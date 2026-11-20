class_name GridBattleAi
extends RefCounted

## How a unit the player does not command takes its turn in a grid battle
## (`AtbBattle`): the move and the action, of those ready
## (`GridUnit.is_ready()`), that do the most good now, a defeat above all and
## a leader's most (damage to its foes, health given back to its hurt side),
## moving first only when that brings a better target in reach or, for the same good,
## a cell fewer of its foes could strike next (`AtbBattle.get_threats()`: an
## archer shoots from where the swordsman cannot reach it), and of those one
## in cover (`BattleGrid.is_cover()`); with nothing in
## reach, a walk toward the nearest foe. A unit whose side takes the goal
## cells (`AtbBattle.takes_goals()`) steps onto one it can reach, winning,
## acting from there if it can, and with nothing in reach walks toward the
## nearest goal instead. It plays the same battle the same way every time. A
## game gives `AtbBattle.ai` one of its own to play otherwise.

## What a defeat is worth on top of the damage that brings it.
const DEFEAT_SCORE := 1000
## What setting back a foe's gauge is worth for each point
## (`AtbBattle.delay_of()`): a whole turn's delay as much as 10 health.
const DELAY_SCORE := 0.1

## Takes `unit`'s turn in `battle`.
func take_turn(battle: AtbBattle, unit: GridUnit) -> void:
	var goal := goal_in_reach(battle, unit)
	if not goal.is_empty() and goal[0] != unit.cell:
		battle.move(unit, goal[0])
	var plan := best_plan(battle, unit, not goal.is_empty())
	if plan.is_empty():
		approach(battle, unit)
		return
	var cell: Vector2i = plan["cell"]
	if cell != unit.cell:
		battle.move(unit, cell)
	battle.act(unit, plan["action"], plan["target"])

## The best of `unit`'s actions from a cell it can stand in now:
## {"cell": Vector2i, "action": BattleActionData, "target": Vector2i,
## "score": int}; for the same score, from the cell the fewest of its foes
## could strike next, in cover before not, then the first found (its own cell
## before the cells it can move to, unless it `stays`); empty when none does
## any good.
func best_plan(battle: AtbBattle, unit: GridUnit, stays := false) -> Dictionary:
	var best := {}
	var best_exposure := 0
	var cells: Array[Vector2i] = [unit.cell]
	if not stays:
		cells.append_array(battle.get_moves(unit))
	var actions := unit.data.get_actions() if not unit.has_acted else [] as Array[BattleActionData]
	if actions.is_empty():
		return best
	var threats := battle.get_threats(unit.faction, unit)
	for cell: Vector2i in cells:
		# How exposed the cell is: the foes that could strike it, then whether
		# it lacks cover.
		var exposure: int = threats.get(cell, 0) * 2 + (0 if battle.grid.is_cover(cell) else 1)
		for action: BattleActionData in actions:
			for target: Vector2i in battle.targets_from(unit, action, cell):
				var value := score(battle, unit, action, target, cell)
				var best_value := int(best.get("score", 0))
				if value > best_value or (value == best_value and value > 0 and exposure < best_exposure):
					best = {"cell": cell, "action": action, "target": target, "score": value}
					best_exposure = exposure
	return best

## What `unit` taking `action` at `target` from `from` is worth: the health
## it takes from foes, with `DEFEAT_SCORE` for each it defeats (and for each
## unit of its side that flees with a leader it defeats) and
## `DELAY_SCORE` for each point of gauge it sets back of those it leaves
## standing, or the health it gives back to its side.
func score(battle: AtbBattle, unit: GridUnit, action: BattleActionData, target: Vector2i, from: Vector2i) -> int:
	var value := 0
	for other: GridUnit in battle.affected_at(unit, action, target, from):
		var amount := battle.amount_of(unit, action, other)
		if action.effect == BattleActionData.Effect.HEAL:
			value += mini(amount, other.health.maximum - other.health.current)
		else:
			value += mini(amount, other.health.current)
			if amount >= other.health.current:
				value += DEFEAT_SCORE * (_side_of(battle, other) if other.leader else 1)
			else:
				value += roundi(battle.delay_of(action, other) * DELAY_SCORE)
	return value

# How many units of `leader`'s faction are in the battle, the leader too.
func _side_of(battle: AtbBattle, leader: GridUnit) -> int:
	return battle.units.filter(func(unit: GridUnit) -> bool: return unit.faction == leader.faction and unit.is_alive()).size()

## The goal cell `unit` stands on or can move to on its turn, when its side
## takes them (`AtbBattle.takes_goals()`): `[cell]`, its own first, then row
## by row; `[]` when there is none.
func goal_in_reach(battle: AtbBattle, unit: GridUnit) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not battle.takes_goals(unit):
		return cells
	if battle.goal_cells.has(unit.cell):
		cells.append(unit.cell)
		return cells
	for cell: Vector2i in battle.get_moves(unit):
		if battle.goal_cells.has(cell):
			cells.append(cell)
			return cells
	return cells

## Moves `unit` as far as it can along the shortest way to the nearest goal
## cell when its side takes them, else (or when no way leads to one) to its
## nearest foe (the earlier placed on a tie); it stays put when no way leads
## to either.
func approach(battle: AtbBattle, unit: GridUnit) -> void:
	var moves := battle.get_moves(unit)
	if moves.is_empty():
		return
	var walls := battle.foe_cells(unit)
	var way: Array[Vector2i] = []
	if battle.takes_goals(unit):
		for cell: Vector2i in battle.goal_cells:
			way = _shorter(way, battle.grid.path(unit.cell, cell, walls))
	if way.is_empty():
		for other: GridUnit in battle.units:
			if other.is_alive() and FactionData.are_hostile(unit.faction, other.faction):
				way = _shorter(way, battle.grid.path(unit.cell, other.cell, walls))
	for index in range(way.size() - 1, -1, -1):
		if moves.has(way[index]):
			battle.move(unit, way[index])
			return

# `way`, unless `other` leads somewhere in fewer steps (the earlier on a tie).
func _shorter(way: Array[Vector2i], other: Array[Vector2i]) -> Array[Vector2i]:
	return other if not other.is_empty() and (way.is_empty() or other.size() < way.size()) else way
