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
## (`SKIP_BONUS`). The battle ends when no two living units are hostile
## (`FactionData.are_hostile()`), won when the player's side is left.
##
## It is plain data, with no node or frame of its own: a view
## (`GridBattleGame`) lets time pass with `advance()`, gives the player's
## commands and shows what the signals say happened. The same battle with the
## same commands at the same times always plays the same way.

signal turn_started(unit: GridUnit)
signal unit_moved(unit: GridUnit, path: Array[Vector2i])
## `hits` holds a {"unit": GridUnit, "amount": int} for each unit it reached:
## the health it took or gave back.
signal unit_acted(unit: GridUnit, action: BattleActionData, cell: Vector2i, hits: Array[Dictionary])
signal unit_defeated(unit: GridUnit)
signal turn_ended(unit: GridUnit)
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
# The player's unit taking its turn, the units of theirs whose gauges filled
# while it does, and the unit the AI moves now.
var _turn: GridUnit
var _waiting: Array[GridUnit] = []
var _ai_turn: GridUnit
var _over := false
var _won := false

func _init(battle_grid: BattleGrid, side: StringName = FactionData.PLAYER) -> void:
	grid = battle_grid
	player_faction = side

## The battle `map` sets up, with time flowing as `settings` say.
static func from_map(map: BattleMapData, settings: TacticsSettings = null) -> AtbBattle:
	var battle := AtbBattle.new(BattleGrid.new(map.size, map.blocked_cells), map.player_faction_id)
	battle.time_flows_while_choosing = settings != null and settings.time_flows_while_choosing
	for placement: BattlePlacement in map.placements:
		var data := BattleUnitData.find(placement.unit_id) if placement != null else null
		if data != null:
			battle.add_unit(data, placement.faction_id, placement.cell)
	return battle

## Places a unit of `data` on `faction`'s side in `cell`; the player commands
## it when `faction` is theirs.
func add_unit(data: BattleUnitData, faction: StringName, cell: Vector2i) -> GridUnit:
	var unit := GridUnit.new(data, faction, cell, units.size(), faction == player_faction)
	units.append(unit)
	return unit

func is_over() -> bool:
	return _over

func is_won() -> bool:
	return _won

## The player's unit that waits for its commands, or null.
func get_turn_unit() -> GridUnit:
	return _turn

## Whether `unit` fights on the player's side.
func is_on_player_side(unit: GridUnit) -> bool:
	return not FactionData.are_hostile(unit.faction, player_faction)

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
		if filling.is_empty():
			return
		var step := left
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
		for unit: GridUnit in full:
			# Once one of the player's units waits, the others that filled
			# with it wait their turn, full, until time flows again.
			if _over or (_turn != null and not time_flows_while_choosing):
				break
			if unit.is_alive():
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
## whose area reaches a unit the action affects.
func targets_from(unit: GridUnit, action: BattleActionData, from: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
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
	unit.cell = cell
	unit.has_moved = true
	unit_moved.emit(unit, walked)
	_end_when_done(unit)
	return true

## Has `unit` take `action`, one of its own, at `cell` on its turn; false, and
## nothing changes, when it is not its turn, it has acted or the action does
## not reach there.
func act(unit: GridUnit, action: BattleActionData, cell: Vector2i) -> bool:
	if _over or not _is_turn(unit) or not unit.data.action_ids.has(action.id) or not get_targets(unit, action).has(cell):
		return false
	unit.has_acted = true
	var hits: Array[Dictionary] = []
	for target: GridUnit in affected_at(unit, action, cell, unit.cell):
		var amount := action.amount_for(unit, target)
		hits.append({"unit": target, "amount": target.health.heal(amount) if action.effect == BattleActionData.Effect.HEAL else target.health.take(amount)})
	unit_acted.emit(unit, action, cell, hits)
	for hit: Dictionary in hits:
		var target: GridUnit = hit["unit"]
		if not target.is_alive():
			_defeat(target)
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

func _is_turn(unit: GridUnit) -> bool:
	return unit != null and (unit == _turn or unit == _ai_turn)

func _on_gauge_full(unit: GridUnit) -> void:
	if unit.player_controlled:
		_waiting.append(unit)
		_start_player_turn()
		return
	_ai_turn = unit
	unit.has_moved = false
	unit.has_acted = false
	turn_started.emit(unit)
	ai.take_turn(self, unit)
	_ai_turn = null
	if not _over and unit.is_alive():
		_finish_turn(unit)

func _start_player_turn() -> void:
	if _over or _turn != null or _waiting.is_empty():
		return
	_turn = _waiting.pop_front()
	_turn.has_moved = false
	_turn.has_acted = false
	turn_started.emit(_turn)

# A player's turn ends by itself once the unit has moved and acted.
func _end_when_done(unit: GridUnit) -> void:
	if unit == _turn and unit.has_moved and unit.has_acted:
		end_turn(unit)

func _finish_turn(unit: GridUnit) -> void:
	unit.gauge = (0.0 if unit.has_moved else SKIP_BONUS) + (0.0 if unit.has_acted else SKIP_BONUS)
	turn_ended.emit(unit)

func _defeat(unit: GridUnit) -> void:
	unit.gauge = 0.0
	_waiting.erase(unit)
	if unit == _turn:
		_turn = null
	unit_defeated.emit(unit)

func _check_over() -> void:
	var alive := units.filter(func(unit: GridUnit) -> bool: return unit.is_alive())
	for unit: GridUnit in alive:
		for other: GridUnit in alive:
			if FactionData.are_hostile(unit.faction, other.faction):
				return
	_end(alive.any(func(unit: GridUnit) -> bool: return is_on_player_side(unit)))

func _end(won: bool) -> void:
	_over = true
	_won = won
	_turn = null
	_waiting.clear()
	ended.emit(won)
