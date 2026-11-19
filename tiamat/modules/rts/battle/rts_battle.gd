class_name RtsBattle
extends RefCounted

## A battle on an open field in real time. Each unit walks where it is
## ordered, around the obstacles (`RtsNavigation`) and out of the other units'
## way, and attacks the foes it reaches once its attack is ready again. The
## player orders the units of their faction (`player_faction`), one or a group
## at a time: move, attack a foe, attack-move, stop, hold. The others, their
## allies among them, march on the nearest foe when the battle says they
## advance (`computer_advances`, `RtsBattleAi`), each in its turn. A unit
## with nothing to do, or attack-moving, goes after the foes it sees and lets
## one go once it gets well out of sight (`LEASH`); a holding unit fights only
## what it reaches.
## The battle ends when no two living units are hostile
## (`FactionData.are_hostile()`), won when the player's side is left. A unit
## that falls is out of the battle for good, even if its health comes back.
##
## It is plain data, with no node or frame of its own: a view
## (`RtsBattleGame`) lets time pass with `advance()`, gives the player's orders
## and shows what the signals say happened. Time passes in fixed steps
## (`STEP`), so the same battle with the same orders at the same times always
## plays the same way.
##
## A step costs about the units near each one rather than every pair of
## units: the battle knows which factions are hostile once (`are_foes()`),
## steps only the living units, files them by where they stand
## (`RtsUnitGrid`) to find the foe a unit sees and the units it overlaps, and
## the units the player does not command think by turns.

signal unit_attacked(attacker: RtsUnit, target: RtsUnit, amount: int)
signal unit_defeated(unit: RtsUnit)
signal ended(won: bool)

## The seconds of one step of the battle.
const STEP := 1.0 / 30.0
## How often a unit going after a foe looks again for the way to it.
const REPATH_SECONDS := 0.5
## How often, in steps, each unit the player does not command thinks
## (`RtsBattleAi`): once a second. They take turns by their place among the
## units, so a large battle does not think all in one step.
const THINK_STEPS := 30
## How far, as a share of its sight, a unit not ordered to attack a foe goes
## after it before it lets it go.
const LEASH := 1.5
## The room between the places of a group sent somewhere together.
const FORMATION_GAP := 2.0
## How near its goal a unit stops, besides its own radius.
const ARRIVE_DISTANCE := 1.0
# Seconds an advance may fall short of a step and still take it, so rounding
# never loses one.
const _EPSILON := 0.000001

var size: Vector2
var navigation: RtsNavigation
var units: Array[RtsUnit] = []
## The player's faction, as the battle was made.
var player_faction: StringName
var computer_advances := true
var ai := RtsBattleAi.new()
## The seconds of battle that have passed.
var time := 0.0
var _left := 0.0
var _steps := 0
var _over := false
var _won := false
# The living units, in the order placed: those a step moves.
var _alive: Array[RtsUnit] = []
# faction -> its place among the factions of the battle (`RtsUnit.side`).
var _sides: Dictionary[StringName, int] = {}
# Whether the factions of two places are hostile, by [first * count + second].
var _hostility := PackedByteArray()
# For each place, the places of the factions hostile to it; and every place.
var _foe_sides: Array[PackedInt32Array] = []
var _every_side := PackedInt32Array()
# The living units by where they stand, filed while a step runs (`_filed`).
var _grid: RtsUnitGrid
var _filed := false
# Whether a unit fell since the living were last counted.
var _fallen := false
# The widest unit's radius, and the most any unit walks in a step.
var _widest_radius := 0.0
var _stride := 0.0

func _init(field_size: Vector2, obstacles: Array[Rect2] = [], side: StringName = FactionData.PLAYER) -> void:
	size = field_size
	navigation = RtsNavigation.new(field_size, obstacles)
	player_faction = side
	_side_of(side)

## The battle `map` sets up.
static func from_map(map: RtsMapData) -> RtsBattle:
	var battle := RtsBattle.new(map.size, map.obstacles, map.player_faction_id)
	battle.computer_advances = map.computer_advances
	for placement: RtsPlacement in map.placements:
		var data := RtsUnitData.find(placement.unit_id) if placement != null else null
		if data != null:
			battle.add_unit(data, placement.faction_id, placement.position)
	return battle

## Places a unit of `data` on `faction`'s side at `point`, or the open point
## nearest it; the player orders it when `faction` is theirs.
func add_unit(data: RtsUnitData, faction: StringName, point: Vector2) -> RtsUnit:
	var unit := RtsUnit.new(data, faction, navigation.get_nearest_open(point), units.size(), faction == player_faction)
	unit.side = _side_of(faction)
	units.append(unit)
	_alive.append(unit)
	_widest_radius = maxf(_widest_radius, data.radius)
	_stride = maxf(_stride, data.move_speed * STEP)
	# One placed while a step runs is not filed: look at every unit until the
	# step files them again.
	_filed = false
	return unit

func is_over() -> bool:
	return _over

func is_won() -> bool:
	return _won

## Whether `unit` fights on the player's side.
func is_on_player_side(unit: RtsUnit) -> bool:
	return _hostility[unit.side * _sides.size() + _sides[player_faction]] == 0

## Whether `first` and `second` fight each other (`FactionData.are_hostile()`,
## asked once per two factions of the battle).
func are_foes(first: RtsUnit, second: RtsUnit) -> bool:
	return _hostility[first.side * _sides.size() + second.side] == 1

## The living unit at `index` among the units, or null.
func get_unit(index: int) -> RtsUnit:
	if index < 0 or index >= units.size() or not units[index].is_alive():
		return null
	return units[index]

## The living units, in the order placed.
func get_living_units() -> Array[RtsUnit]:
	return _alive.filter(func(unit: RtsUnit) -> bool: return unit.is_alive())

## The living units the player orders.
func get_player_units() -> Array[RtsUnit]:
	return _alive.filter(func(unit: RtsUnit) -> bool: return unit.is_alive() and unit.player_controlled)

## The living unit whose body covers `point`, grown by `slack`, the nearest
## first; null when there is none.
func get_unit_at(point: Vector2, slack := 0.0) -> RtsUnit:
	var found: RtsUnit
	var nearest := INF
	for unit: RtsUnit in _alive:
		var distance := unit.position.distance_to(point)
		if unit.is_alive() and distance <= unit.data.radius + slack and distance < nearest:
			found = unit
			nearest = distance
	return found

## The living units whose middle lies in `rect`.
func get_units_in(rect: Rect2) -> Array[RtsUnit]:
	var area := rect.abs().grow(0.001)
	return _alive.filter(func(unit: RtsUnit) -> bool: return unit.is_alive() and area.has_point(unit.position))

## The nearest living foe of `unit` whose edge is at most `within` from its
## edge, or null; of two as near, the earlier placed.
func get_nearest_foe(unit: RtsUnit, within := INF) -> RtsUnit:
	var candidates := _alive
	if _filed and not is_inf(within):
		# The foes filed at the start of the step, since when any unit walked
		# a stride at most.
		candidates = _grid.get_near(unit.position, within + unit.data.radius + _widest_radius + _stride, _foe_sides[unit.side])
	var found: RtsUnit
	var nearest := within
	for other: RtsUnit in candidates:
		if other != unit and other.is_alive() and are_foes(unit, other):
			var gap := unit.get_gap_to(other)
			if gap <= nearest and (found == null or gap < nearest or other.index < found.index):
				found = other
				nearest = gap
	return found

## Lets `seconds` of battle time pass, a step (`STEP`) at a time.
func advance(seconds: float) -> void:
	_left += seconds
	while _left + _EPSILON >= STEP and not _over:
		_left -= STEP
		_step()
	if _over:
		_left = 0.0

## Sends `group` to `point`, each unit to its own place around it: passing foes
## by, or fighting the foes they see on the way (`attack_move`).
func order_move(group: Array[RtsUnit], point: Vector2, attack_move := false) -> void:
	var living := _living(group)
	var places := get_formation(living.size(), point, _widest(living) * 2.0 + FORMATION_GAP)
	# The unit nearest the point takes the place nearest it, and so on out.
	living.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool:
		var a_distance := a.position.distance_squared_to(point)
		var b_distance := b.position.distance_squared_to(point)
		return a_distance < b_distance or (a_distance == b_distance and a.index < b.index))
	for slot in living.size():
		var unit := living[slot]
		unit.order = RtsUnit.Order.ATTACK_MOVE if attack_move else RtsUnit.Order.MOVE
		unit.goal = places[slot]
		unit.target_index = -1
		_find_path(unit, unit.goal)

## Sends `group` after `target` until it falls; units of its own side are not
## sent.
func order_attack(group: Array[RtsUnit], target: RtsUnit) -> void:
	if target == null or not target.is_alive():
		return
	for unit: RtsUnit in _living(group):
		if FactionData.are_hostile(unit.faction, target.faction):
			unit.order = RtsUnit.Order.ATTACK
			unit.target_index = target.index
			_clear_path(unit)

## What a right click at `point` orders `group`: to attack the foe there, else
## to move there.
func order_at(group: Array[RtsUnit], point: Vector2, slack := 0.0) -> void:
	var living := _living(group)
	if living.is_empty():
		return
	var target := get_unit_at(point, slack)
	if target != null and FactionData.are_hostile(living[0].faction, target.faction):
		order_attack(living, target)
	else:
		order_move(living, point)

## Has `group` stop what it does; they go after the foes they see again.
func order_stop(group: Array[RtsUnit]) -> void:
	_set_still(group, RtsUnit.Order.IDLE)

## Has `group` stay where they stand and fight only what they reach.
func order_hold(group: Array[RtsUnit]) -> void:
	_set_still(group, RtsUnit.Order.HOLD)

## Ends the battle lost, as when the player gives it up.
func forfeit() -> void:
	if _over:
		return
	_over = true
	_won = false
	ended.emit(false)

## The places of `count` units sent to `point` together, `spacing` apart in
## rows and columns around it, the nearest to it first, each moved to an open
## point when it is not one.
func get_formation(count: int, point: Vector2, spacing: float) -> Array[Vector2]:
	var places: Array[Vector2] = []
	if count <= 0:
		return places
	var columns := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / columns)
	var offsets: Array[Vector2] = []
	for row in rows:
		for column in columns:
			offsets.append((Vector2(column, row) - Vector2(columns - 1, rows - 1) * 0.5) * spacing)
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var a_length := a.length_squared()
		var b_length := b.length_squared()
		return a_length < b_length or (a_length == b_length and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for slot in count:
		places.append(navigation.get_nearest_open(point + offsets[slot]))
	return places

func _step() -> void:
	time += STEP
	var turn := _steps % THINK_STEPS
	_steps += 1
	_file_units()
	for unit: RtsUnit in _alive:
		if _over:
			break
		if not unit.is_alive():
			# One that fell outside a step.
			_fallen = true
			continue
		if not unit.player_controlled and unit.index % THINK_STEPS == turn:
			ai.think(self, unit)
		_update(unit)
	if _fallen:
		_fallen = false
		_alive = get_living_units()
	if not _over:
		_file_units()
		_separate()
	_filed = false

# Files the living units by where they stand now, in cells three times as
# wide as the widest unit.
func _file_units() -> void:
	var side := maxf(_widest_radius * 6.0, RtsNavigation.CELL_SIZE)
	if _grid == null or _grid.cell_size != side:
		_grid = RtsUnitGrid.new(side)
	_grid.fill(_alive, _sides.size())
	_filed = true

func _update(unit: RtsUnit) -> void:
	unit.cooldown = maxf(unit.cooldown - STEP, 0.0)
	unit.repath_left -= STEP
	var target := _choose_target(unit)
	if target != null:
		if unit.reaches(target):
			_clear_path(unit)
			if unit.cooldown <= 0.0:
				_attack(unit, target)
		elif unit.order != RtsUnit.Order.HOLD:
			if unit.path.is_empty() or unit.repath_left <= 0.0:
				_find_path(unit, target.position)
			if not _walk(unit):
				unit.repath_left = 0.0
		return
	if unit.order != RtsUnit.Order.MOVE and unit.order != RtsUnit.Order.ATTACK_MOVE:
		return
	if unit.path.is_empty() and unit.path_end != unit.goal:
		# Back on its way after going after a foe.
		_find_path(unit, unit.goal)
	if not _walk(unit):
		_find_path(unit, unit.goal)
	elif unit.path.is_empty() or unit.position.distance_to(unit.goal) <= unit.data.radius + ARRIVE_DISTANCE:
		unit.order = RtsUnit.Order.IDLE
		_clear_path(unit)

# The foe `unit` fights or goes after now, as its order lets it; null when it
# has none.
func _choose_target(unit: RtsUnit) -> RtsUnit:
	var current := get_unit(unit.target_index)
	match unit.order:
		RtsUnit.Order.MOVE:
			return null
		RtsUnit.Order.ATTACK:
			if current != null:
				return current
			unit.order = RtsUnit.Order.IDLE
			_clear_path(unit)
		RtsUnit.Order.HOLD:
			if current != null and unit.reaches(current):
				return current
			return _take_target(unit, get_nearest_foe(unit, unit.data.attack_range))
	if current != null and unit.get_gap_to(current) <= unit.data.sight_range * LEASH:
		return current
	return _take_target(unit, get_nearest_foe(unit, unit.data.sight_range))

func _take_target(unit: RtsUnit, target: RtsUnit) -> RtsUnit:
	var index := target.index if target != null else -1
	if index != unit.target_index:
		unit.target_index = index
		_clear_path(unit)
	return target

func _attack(unit: RtsUnit, target: RtsUnit) -> void:
	unit.cooldown = unit.data.attack_cooldown
	var amount := target.health.take(maxi(unit.data.damage - target.data.armor, 1))
	unit_attacked.emit(unit, target, amount)
	if not target.is_alive():
		_fallen = true
		unit_defeated.emit(target)
		_check_over()

# Walks `unit` along its path for a step; false when the next point of the
# way is not open (another unit pushed it off its line).
func _walk(unit: RtsUnit) -> bool:
	var budget := unit.data.move_speed * STEP
	while budget > 0.0 and not unit.path.is_empty():
		var next := unit.path[0]
		var distance := unit.position.distance_to(next)
		var point := next if distance <= budget else unit.position + (next - unit.position) * (budget / distance)
		if not navigation.is_open(point):
			return false
		unit.position = point
		if distance <= budget:
			unit.path.remove_at(0)
		budget -= distance
	return true

func _find_path(unit: RtsUnit, point: Vector2) -> void:
	unit.path = navigation.find_path(unit.position, point)
	unit.path_end = point
	unit.repath_left = REPATH_SECONDS

# Drops the way `unit` walks, so that it finds one again when it next moves:
# after a foe, or back towards its goal once the fight is over.
func _clear_path(unit: RtsUnit) -> void:
	unit.path.clear()
	unit.path_end = Vector2.INF
	unit.repath_left = 0.0

# Pushes apart each two living units whose bodies overlap: half each, or all
# of it on the one that does not hold. A push into the closed part of the
# field slides along it, or is left out. Each two are found through the
# filing; two that the pushes before theirs brought together part in the
# next step.
func _separate() -> void:
	for first: RtsUnit in _alive:
		if not first.is_alive():
			continue
		for second: RtsUnit in _grid.get_near(first.position, first.data.radius + _widest_radius * 2.0, _every_side):
			if second.index <= first.index or not second.is_alive():
				continue
			var apart := second.position - first.position
			var reach := first.data.radius + second.data.radius
			var distance_squared := apart.length_squared()
			if distance_squared >= reach * reach:
				continue
			var distance := sqrt(distance_squared)
			# Two units on one point part along a direction of their own.
			var away := apart / distance if distance > 0.001 else Vector2.RIGHT.rotated(second.index * 2.39996)
			var share := 0.5
			if first.order == RtsUnit.Order.HOLD and second.order != RtsUnit.Order.HOLD:
				share = 0.0
			elif second.order == RtsUnit.Order.HOLD and first.order != RtsUnit.Order.HOLD:
				share = 1.0
			var overlap := reach - distance
			_nudge(first, -away * overlap * share)
			_nudge(second, away * overlap * (1.0 - share))

func _nudge(unit: RtsUnit, offset: Vector2) -> void:
	if offset == Vector2.ZERO:
		return
	for point: Vector2 in [unit.position + offset, unit.position + Vector2(offset.x, 0.0), unit.position + Vector2(0.0, offset.y)]:
		# The whole way open, not only its end: a hard push never jumps a wall.
		if navigation.is_open(point) and navigation.is_line_open(unit.position, point):
			unit.position = point
			return

# Ends the battle once no two living units are foes: one of each faction
# left stands for all of it.
func _check_over() -> void:
	var standing: Array[RtsUnit] = []
	var seen := PackedByteArray()
	seen.resize(_sides.size())
	for unit: RtsUnit in _alive:
		if unit.is_alive() and seen[unit.side] == 0:
			seen[unit.side] = 1
			standing.append(unit)
	for first: RtsUnit in standing:
		for second: RtsUnit in standing:
			if are_foes(first, second):
				return
	_over = true
	_won = standing.any(func(unit: RtsUnit) -> bool: return is_on_player_side(unit))
	ended.emit(_won)

func _set_still(group: Array[RtsUnit], order: RtsUnit.Order) -> void:
	for unit: RtsUnit in _living(group):
		unit.order = order
		unit.target_index = -1
		_clear_path(unit)

func _living(group: Array[RtsUnit]) -> Array[RtsUnit]:
	return group.filter(func(unit: RtsUnit) -> bool: return unit != null and unit.is_alive())

# The place of `faction` among the factions of the battle; a faction new to
# it learns its hostility to every other.
func _side_of(faction: StringName) -> int:
	if _sides.has(faction):
		return _sides[faction]
	_sides[faction] = _sides.size()
	var factions := _sides.keys()
	var count := factions.size()
	_hostility.resize(count * count)
	_foe_sides.resize(count)
	_every_side.append(count - 1)
	for first: int in count:
		_foe_sides[first] = PackedInt32Array()
		for second: int in count:
			var hostile := FactionData.are_hostile(factions[first], factions[second])
			_hostility[first * count + second] = 1 if hostile else 0
			if hostile:
				_foe_sides[first].append(second)
	return _sides[faction]

func _widest(group: Array[RtsUnit]) -> float:
	var widest := 0.0
	for unit: RtsUnit in group:
		widest = maxf(widest, unit.data.radius)
	return widest
