class_name GridBattleAi
extends RefCounted

## How a unit the player does not command takes its turn in a grid battle
## (`AtbBattle`): the move and action that do the most good now, a defeat
## above all (damage to its foes, health given back to its hurt side), moving
## first only when that brings a better target in reach; with nothing in
## reach, a walk toward the nearest foe. It plays the same battle the same way
## every time. A game gives `AtbBattle.ai` one of its own to play otherwise.

## What a defeat is worth on top of the damage that brings it.
const DEFEAT_SCORE := 1000

## Takes `unit`'s turn in `battle`.
func take_turn(battle: AtbBattle, unit: GridUnit) -> void:
	var plan := best_plan(battle, unit)
	if plan.is_empty():
		approach(battle, unit)
		return
	var cell: Vector2i = plan["cell"]
	if cell != unit.cell:
		battle.move(unit, cell)
	battle.act(unit, plan["action"], plan["target"])

## The best of `unit`'s actions from a cell it can stand in now:
## {"cell": Vector2i, "action": BattleActionData, "target": Vector2i,
## "score": int}, the first found on a tie (its own cell before the cells it
## can move to); empty when none does any good.
func best_plan(battle: AtbBattle, unit: GridUnit) -> Dictionary:
	var best := {}
	var cells: Array[Vector2i] = [unit.cell]
	cells.append_array(battle.get_moves(unit))
	var actions := unit.data.get_actions() if not unit.has_acted else [] as Array[BattleActionData]
	for cell: Vector2i in cells:
		for action: BattleActionData in actions:
			for target: Vector2i in battle.targets_from(unit, action, cell):
				var value := score(battle, unit, action, target, cell)
				if value > int(best.get("score", 0)):
					best = {"cell": cell, "action": action, "target": target, "score": value}
	return best

## What `unit` taking `action` at `target` from `from` is worth: the health
## it takes from foes, with `DEFEAT_SCORE` for each it defeats, or the health
## it gives back to its side.
func score(battle: AtbBattle, unit: GridUnit, action: BattleActionData, target: Vector2i, from: Vector2i) -> int:
	var value := 0
	for other: GridUnit in battle.affected_at(unit, action, target, from):
		var amount := action.amount_for(unit, other)
		if action.effect == BattleActionData.Effect.HEAL:
			value += mini(amount, other.health.maximum - other.health.current)
		else:
			value += mini(amount, other.health.current)
			if amount >= other.health.current:
				value += DEFEAT_SCORE
	return value

## Moves `unit` as far as it can along the shortest way to its nearest foe
## (the earlier placed on a tie); it stays put when no way leads to one.
func approach(battle: AtbBattle, unit: GridUnit) -> void:
	var moves := battle.get_moves(unit)
	if moves.is_empty():
		return
	var walls := battle.foe_cells(unit)
	var way: Array[Vector2i] = []
	for other: GridUnit in battle.units:
		if not other.is_alive() or not FactionData.are_hostile(unit.faction, other.faction):
			continue
		var to_foe := battle.grid.path(unit.cell, other.cell, walls)
		if not to_foe.is_empty() and (way.is_empty() or to_foe.size() < way.size()):
			way = to_foe
	for index in range(way.size() - 1, -1, -1):
		if moves.has(way[index]):
			battle.move(unit, way[index])
			return
