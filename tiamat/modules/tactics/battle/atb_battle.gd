class_name AtbBattle
extends RefCounted

## A battle on a grid (`BattleGrid`) in active time. Every unit's gauge fills
## at its speed, and a unit whose gauge is full takes a turn, in which it may
## move once and act once, in either order; units that fill at the same moment
## go in the order they were placed. The player commands the units of their
## faction (`player_faction`); the others, their allies among them, take their
## turns at once (`GridBattleAi`). While one of the player's units waits for
## its commands, time stands still, unless it flows while the player chooses
## (`time_flows_while_choosing`): then the gauges go on filling and the foes go
## on acting. A unit that skips its move or its action comes back sooner
## (`SKIP_BONUS`). Until one of the player's units acts, the player may take
## its move back (`undo_move()`), unless a foe took a turn since or someone
## stands where it came from. The cells the foes could strike on their next
## turns (`get_danger()`) tell the player where a unit stands safe, and a unit
## in cover (`BattleGrid.is_cover()`) takes less damage (`amount_of()`). An
## action that recharges (`BattleActionData.recharge_turns`) waits that many of
## its user's turns before the user may take it again, and one that delays
## (`BattleActionData.delay`) sets back the gauges of the foes it leaves
## standing (`delay_of()`), a player's unit that waited for its turn too. A
## side with a leader (`GridUnit.leader`) flees the battle once the leader
## falls (`unit_fled`), and turns back its units still on their way. Units may
## arrive while the battle runs (`add_arrival()`, `unit_arrived`), in battle
## time (`time`), which stands still with the gauges. The battle ends when no
## two units, living or on their way, are hostile (`FactionData.are_hostile()`),
## won when the player's side is left, or once a unit of the side that takes
## the goal cells (`goal_cells`, `takes_goals()`) ends its turn on one, won
## when that side is the player's (`goal_taken`).
##
## It is plain data, with no node or frame of its own: a view
## (`GridBattleGame`) lets time pass with `advance()`, gives the player's
## commands and shows what the signals say happened. The same battle with the
## same commands at the same times always plays the same way.

signal turn_started(unit: GridUnit)
signal unit_moved(unit: GridUnit, path: Array[Vector2i])
## The player took back the move of `unit` (`undo_move()`): it stands where
## its turn found it again.
signal move_undone(unit: GridUnit)
## `hits` holds a {"unit": GridUnit, "amount": int} for each unit it reached:
## the health it took or gave back, and with an action that delays, "delay":
## how far it set back the unit's gauge.
signal unit_acted(unit: GridUnit, action: BattleActionData, cell: Vector2i, hits: Array[Dictionary])
signal unit_defeated(unit: GridUnit)
## `unit` left the battle when the leader of its side fell.
signal unit_fled(unit: GridUnit)
signal turn_ended(unit: GridUnit)
## `unit` ended its turn on a goal cell, winning the battle for its side.
signal goal_taken(unit: GridUnit)
## `unit` arrived on the grid (`add_arrival()`).
signal unit_arrived(unit: GridUnit)
signal ended(won: bool)

## Where a gauge is full.
const GAUGE_FULL := 100.0
## How far a unit's gauge starts toward its next turn for each of its move and
## its action it skipped.
const SKIP_BONUS := 25.0
# Seconds a gauge may be short of full when time stops and still count as
# full, so rounding never leaves it a hair short.
const _EPSILON := 0.000001

var grid: BattleGrid
var units: Array[GridUnit] = []
var player_faction: StringName
var time_flows_while_choosing := false
var ai := GridBattleAi.new()
## The health the units hostile to the player's side start with, as a share of
## their kind's (`BattleUnitData.max_health`): the player's foe strength.
var foe_health_scale := 1.0
## The cells a side wins the battle by taking (`BattleMapData.goal_cells`),
## and the faction of that side (at first the player's).
var goal_cells: Dictionary[Vector2i, bool] = {}
var goal_faction: StringName
## The units on their way (`add_arrival()`).
var arrivals := GridArrivals.new()
## The seconds of battle time that have passed: the time the gauges fill in.
var time := 0.0
# The player's unit taking its turn, the units of theirs whose gauges filled
# while it does, and the unit the AI moves now.
var _turn: GridUnit
var _waiting: Array[GridUnit] = []
var _ai_turn: GridUnit
# The player's unit whose move may be taken back, and the cell it came from.
var _undo_unit: GridUnit
var _undo_cell: Vector2i
var _over := false
var _won := false

func _init(battle_grid: BattleGrid, side: StringName = FactionData.PLAYER) -> void:
	grid = battle_grid
	player_faction = side
	goal_faction = side

## The battle `map` sets up, with time flowing as `settings` say and the
## player's foes starting with `foe_health` of their kinds' health: each unit
## whose placement's condition holds (`BattlePlacement.joins()`), there at the
## start or on its way (`BattlePlacement.arrive_seconds`).
static func from_map(map: BattleMapData, settings: TacticsSettings = null, foe_health := 1.0) -> AtbBattle:
	var grid := BattleGrid.new(map.size, map.blocked_cells, map.cover_cells, map.cover_reduction)
	grid.set_rough(map.rough_cells, map.rough_cost)
	var battle := AtbBattle.new(grid, map.player_faction_id)
	battle.time_flows_while_choosing = settings != null and settings.time_flows_while_choosing
	battle.foe_health_scale = foe_health
	for cell: Vector2i in map.goal_cells:
		battle.goal_cells[cell] = true
	battle.goal_faction = map.get_goal_faction()
	for placement: BattlePlacement in map.placements:
		var data := BattleUnitData.find(placement.unit_id) if placement != null and placement.joins() else null
		if data != null:
			battle.add_arrival(data, placement.faction_id, placement.cell, placement.arrive_seconds, placement.leader)
	return battle

## Places a unit of `data` on `faction`'s side in `cell`; the player commands
## it when `faction` is theirs, and it starts with `foe_health_scale` of its
## kind's health when it is hostile to them.
func add_unit(data: BattleUnitData, faction: StringName, cell: Vector2i) -> GridUnit:
	var unit := GridUnit.new(data, faction, cell, units.size(), faction == player_faction)
	if foe_health_scale != 1.0 and FactionData.are_hostile(faction, player_faction):
		unit.health.reset(roundi(data.max_health * foe_health_scale))
	units.append(unit)
	return unit

## Has a unit of `data` on `faction`'s side, leading it with `leader`, arrive
## in `cell`, or the open cell nearest it that no unit stands in, once
## `seconds` of battle time have passed, its gauge empty; one due now or
## before is placed at once.
func add_arrival(data: BattleUnitData, faction: StringName, cell: Vector2i, seconds: float, leader := false) -> void:
	if seconds <= time + _EPSILON:
		add_unit(data, faction, cell).leader = leader
	else:
		arrivals.add(data, faction, cell, seconds, leader)

func is_over() -> bool:
	return _over

func is_won() -> bool:
	return _won

## The player's unit that waits for its commands, or null.
func get_turn_unit() -> GridUnit:
	return _turn

## The units whose turns come after the one now, soonest first, `count` of
## them, as the gauges will fill: the player's units that wait, full, first,
## then each unit's turns in turn, every one of them as though the unit moved
## and acted (the unit whose turn it is now from an empty gauge); units that
## fill at the same moment in the order they were placed.
func get_turn_order(count: int) -> Array[GridUnit]:
	var order: Array[GridUnit] = []
	# When each unit fills next, in battle time from now.
	var next: Dictionary[GridUnit, float] = {}
	for unit: GridUnit in units:
		if not unit.is_alive() or unit.data.speed <= 0.0:
			continue
		if _waiting.has(unit):
			next[unit] = GAUGE_FULL / unit.data.speed
		else:
			next[unit] = (GAUGE_FULL - (0.0 if unit == _turn else unit.gauge)) / unit.data.speed
	for unit: GridUnit in _waiting:
		if order.size() < count:
			order.append(unit)
	while order.size() < count and not next.is_empty():
		var soonest: GridUnit = null
		for unit: GridUnit in next:
			if soonest == null or next[unit] < next[soonest] - _EPSILON or (next[unit] <= next[soonest] + _EPSILON and unit.index < soonest.index):
				soonest = unit
		order.append(soonest)
		next[soonest] += GAUGE_FULL / soonest.data.speed
	return order

## Whether `unit` fights on the player's side.
func is_on_player_side(unit: GridUnit) -> bool:
	return not FactionData.are_hostile(unit.faction, player_faction)

## Whether `unit` fights on the side that takes the goal cells, which the
## battle has.
func takes_goals(unit: GridUnit) -> bool:
	return not goal_cells.is_empty() and not FactionData.are_hostile(unit.faction, goal_faction)

## The living unit in `cell`, or null.
func get_unit_at(cell: Vector2i) -> GridUnit:
	for unit: GridUnit in units:
		if unit.cell == cell and unit.is_alive():
			return unit
	return null

## Lets `seconds` of battle time pass: the gauges fill, and each unit whose
## gauge fills takes its turn then.
func advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _over and (_turn == null or time_flows_while_choosing):
		var filling := units.filter(func(unit: GridUnit) -> bool: return unit.is_alive() and unit.data.speed > 0.0 and unit != _turn and not _waiting.has(unit))
		if filling.is_empty() and arrivals.size() == 0:
			return
		var step := clampf(arrivals.get_next() - time, 0.0, left)
		for unit: GridUnit in filling:
			step = minf(step, (GAUGE_FULL - unit.gauge) / unit.data.speed)
		var full: Array[GridUnit] = []
		for unit: GridUnit in filling:
			# The one that sets the step fills exactly, whatever the rounding.
			if (GAUGE_FULL - unit.gauge) / unit.data.speed <= step + _EPSILON:
				unit.gauge = GAUGE_FULL
				full.append(unit)
			else:
				unit.gauge += unit.data.speed * step
		left -= step
		time += step
		for arrival: GridArrivals.Arrival in arrivals.take_due(time + _EPSILON):
			_arrive(arrival)
		for unit: GridUnit in full:
			# Once one of the player's units waits, the others that filled
			# with it wait their turn, full, until time flows again.
			if _over or (_turn != null and not time_flows_while_choosing):
				break
			# One delayed by a unit that filled with it fills again first.
			if unit.is_alive() and unit.gauge >= GAUGE_FULL:
				_on_gauge_full(unit)

## Where `unit` may move on its turn: the cells it walks to within its move,
## past its side's units but not its foes', that no unit stands on, row by
## row; none once it has moved.
func get_moves(unit: GridUnit) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if unit.has_moved or not unit.is_alive():
		return cells
	for cell: Vector2i in grid.walk(unit.cell, unit.data.move, foe_cells(unit)):
		if get_unit_at(cell) == null:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells

## The cells `unit` may aim `action` at on its turn; none once it has acted.
func get_targets(unit: GridUnit, action: BattleActionData) -> Array[Vector2i]:
	if unit.has_acted or not unit.is_alive():
		return [] as Array[Vector2i]
	return targets_from(unit, action, unit.cell)

## The cells `unit` could aim `action` at if it stood in `from`: those in range
## whose area reaches a unit the action affects; none while the action
## recharges (`GridUnit.is_ready()`).
func targets_from(unit: GridUnit, action: BattleActionData, from: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not unit.is_ready(action):
		return cells
	for cell: Vector2i in grid.cells_in_range(from, action.min_range, action.max_range):
		if not affected_at(unit, action, cell, from).is_empty():
			cells.append(cell)
	return cells

## The units `action` reaches when `unit`, standing in `from`, aims it at
## `cell`.
func affected_at(unit: GridUnit, action: BattleActionData, cell: Vector2i, from: Vector2i) -> Array[GridUnit]:
	var reached: Array[GridUnit] = []
	for other: GridUnit in units:
		var other_cell := from if other == unit else other.cell
		if other.is_alive() and BattleGrid.distance(other_cell, cell) <= action.area and action.affects(unit.faction, other.faction):
			reached.append(other)
	return reached

## The open cells where a foe of the player's side could strike on its next
## turn, as everyone stands now (`get_threats()` of the player's faction).
## `moving`, the player's unit choosing where to go, counts as gone from its
## cell, so a foe may walk through it.
func get_danger(moving: GridUnit = null) -> Dictionary[Vector2i, bool]:
	var danger: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in get_threats(player_faction, moving):
		danger[cell] = true
	return danger

## How many living units hostile to `faction` could strike each open cell on
## their next turns, as everyone stands now (`GridThreats.count()`); `moving`
## counts as gone from its cell, so they may walk through it.
func get_threats(faction: StringName, moving: GridUnit = null) -> Dictionary[Vector2i, int]:
	return GridThreats.count(self, faction, moving)

## What `action` of `unit` takes from or gives to `target` where it stands:
## damage less in cover (`BattleGrid.damage_on()`).
func amount_of(unit: GridUnit, action: BattleActionData, target: GridUnit) -> int:
	var amount := action.amount_for(unit, target)
	return grid.damage_on(target.cell, amount) if action.effect == BattleActionData.Effect.DAMAGE else amount

## How far `action` would set back the gauge of `target` (`BattleActionData.delay`):
## no further than empty, and not at all for a unit taking its turn now.
func delay_of(action: BattleActionData, target: GridUnit) -> float:
	if action.effect != BattleActionData.Effect.DAMAGE or action.delay <= 0.0 or target == _turn or target == _ai_turn:
		return 0.0
	return minf(action.delay, target.gauge)

## What `unit` taking `action` at `cell` from where it stands would do, told
## before it does: a {"unit": GridUnit, "amount": int, "defeats": bool} for
## each unit it reaches, the health it would take (no more than the unit has)
## or give back (no more than it lacks), and with an action that delays,
## "delay": how far it would set back the gauge of a unit it leaves standing,
## just as `act()` then does.
func forecast(unit: GridUnit, action: BattleActionData, cell: Vector2i) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for target: GridUnit in affected_at(unit, action, cell, unit.cell):
		var amount := amount_of(unit, action, target)
		var hit: Dictionary
		if action.effect == BattleActionData.Effect.HEAL:
			hit = {"unit": target, "amount": mini(amount, target.health.maximum - target.health.current), "defeats": false}
		else:
			hit = {"unit": target, "amount": mini(amount, target.health.current), "defeats": amount >= target.health.current}
		if action.delay > 0.0 and action.effect == BattleActionData.Effect.DAMAGE:
			hit["delay"] = 0.0 if hit["defeats"] else delay_of(action, target)
		hits.append(hit)
	return hits

## The cells of the living units hostile to `unit`.
func foe_cells(unit: GridUnit) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for other: GridUnit in units:
		if other.is_alive() and FactionData.are_hostile(unit.faction, other.faction):
			cells[other.cell] = true
	return cells

## Moves `unit` to `cell` on its turn; false, and nothing changes, when it is
## not its turn, it has moved or it cannot go there.
func move(unit: GridUnit, cell: Vector2i) -> bool:
	if _over or not _is_turn(unit) or not get_moves(unit).has(cell):
		return false
	var walked := grid.path(unit.cell, cell, foe_cells(unit))
	if unit == _turn:
		_undo_unit = unit
		_undo_cell = unit.cell
	unit.cell = cell
	unit.has_moved = true
	unit_moved.emit(unit, walked)
	_end_when_done(unit)
	return true

## Whether the player may take back the move of `unit`, whose turn it is: it
## has moved and not acted, no foe took a turn since (as one may while time
## flows while the player chooses), and no one stands where it came from.
func can_undo_move(unit: GridUnit) -> bool:
	return not _over and unit != null and unit == _turn and unit == _undo_unit and unit.has_moved \
		and not unit.has_acted and get_unit_at(_undo_cell) == null

## Takes back the move of the player's `unit` (`can_undo_move()`): it stands
## where it came from and may move again; false, and nothing changes, when it
## may not.
func undo_move(unit: GridUnit) -> bool:
	if not can_undo_move(unit):
		return false
	unit.cell = _undo_cell
	unit.has_moved = false
	_undo_unit = null
	move_undone.emit(unit)
	return true

## Has `unit` take `action`, one of its own, at `cell` on its turn; false, and
## nothing changes, when it is not its turn, it has acted or the action does
## not reach there.
func act(unit: GridUnit, action: BattleActionData, cell: Vector2i) -> bool:
	if _over or not _is_turn(unit) or not unit.data.action_ids.has(action.id) or not get_targets(unit, action).has(cell):
		return false
	unit.has_acted = true
	unit.use(action)
	_undo_unit = null
	var hits: Array[Dictionary] = []
	for target: GridUnit in affected_at(unit, action, cell, unit.cell):
		var amount := amount_of(unit, action, target)
		var hit := {"unit": target, "amount": target.health.heal(amount) if action.effect == BattleActionData.Effect.HEAL else target.health.take(amount)}
		if action.delay > 0.0 and action.effect == BattleActionData.Effect.DAMAGE:
			hit["delay"] = _set_back(target, delay_of(action, target)) if target.is_alive() else 0.0
		hits.append(hit)
	unit_acted.emit(unit, action, cell, hits)
	for hit: Dictionary in hits:
		var target: GridUnit = hit["unit"]
		if target.health.is_depleted():
			_defeat(target)
	for hit: Dictionary in hits:
		var fallen: GridUnit = hit["unit"]
		if fallen.leader and fallen.health.is_depleted():
			_rout(fallen)
	_check_over()
	if not _over:
		_end_when_done(unit)
		_start_player_turn()
	return true

## Ends the turn of the player's `unit`; false when it is not taking one.
func end_turn(unit: GridUnit) -> bool:
	if _over or unit == null or unit != _turn:
		return false
	_turn = null
	_finish_turn(unit)
	_start_player_turn()
	return true

## The player gives up: the battle ends, lost.
func forfeit() -> void:
	if not _over:
		_end(false)

# Sets back `unit`'s gauge by `amount`; a player's unit that waited, full,
# for its turn waits no more.
func _set_back(unit: GridUnit, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	unit.gauge -= amount
	_waiting.erase(unit)
	return amount

func _is_turn(unit: GridUnit) -> bool:
	return unit != null and (unit == _turn or unit == _ai_turn)

func _on_gauge_full(unit: GridUnit) -> void:
	if unit.player_controlled:
		_waiting.append(unit)
		_start_player_turn()
		return
	_ai_turn = unit
	_undo_unit = null
	unit.start_turn()
	turn_started.emit(unit)
	ai.take_turn(self, unit)
	_ai_turn = null
	if not _over and unit.is_alive():
		_finish_turn(unit)

func _start_player_turn() -> void:
	if _over or _turn != null or _waiting.is_empty():
		return
	_turn = _waiting.pop_front()
	_undo_unit = null
	_turn.start_turn()
	turn_started.emit(_turn)

# A player's turn ends by itself once the unit has moved and acted.
func _end_when_done(unit: GridUnit) -> void:
	if unit == _turn and unit.has_moved and unit.has_acted:
		end_turn(unit)

func _finish_turn(unit: GridUnit) -> void:
	unit.gauge = (0.0 if unit.has_moved else SKIP_BONUS) + (0.0 if unit.has_acted else SKIP_BONUS)
	turn_ended.emit(unit)
	if goal_cells.has(unit.cell) and takes_goals(unit) and unit.is_alive():
		goal_taken.emit(unit)
		_end(is_on_player_side(unit))

func _defeat(unit: GridUnit) -> void:
	unit.gauge = 0.0
	_waiting.erase(unit)
	if unit == _turn:
		_turn = null
	unit_defeated.emit(unit)

# The rest of `leader`'s faction flees the battle, and its units on their way
# turn back.
func _rout(leader: GridUnit) -> void:
	arrivals.remove_faction(leader.faction)
	for unit: GridUnit in units:
		if unit != leader and unit.faction == leader.faction and unit.is_alive():
			unit.fled = true
			unit.gauge = 0.0
			_waiting.erase(unit)
			if unit == _turn:
				_turn = null
			unit_fled.emit(unit)

func _check_over() -> void:
	var factions := arrivals.get_factions()
	for unit: GridUnit in units:
		if unit.is_alive() and not factions.has(unit.faction):
			factions.append(unit.faction)
	for faction: StringName in factions:
		for other: StringName in factions:
			if FactionData.are_hostile(faction, other):
				return
	_end(factions.any(func(faction: StringName) -> bool: return not FactionData.are_hostile(faction, player_faction)))

# Places the unit of `arrival` in its cell, or the open cell nearest it that
# no unit stands in; none is placed while every cell is taken.
func _arrive(arrival: GridArrivals.Arrival) -> void:
	for reach: int in maxi(grid.size.x, grid.size.y) * 2:
		for cell: Vector2i in grid.cells_in_range(arrival.cell, reach, reach):
			if grid.is_open(cell) and get_unit_at(cell) == null:
				var unit := add_unit(arrival.data, arrival.faction, cell)
				unit.leader = arrival.leader
				unit_arrived.emit(unit)
				return

func _end(won: bool) -> void:
	_over = true
	_won = won
	_turn = null
	_waiting.clear()
	ended.emit(won)
