class_name GridThreats
extends RefCounted

## Where the units of a grid battle (`AtbBattle`) could strike on their next
## turns, as everyone stands now: what `AtbBattle.get_threats()` and
## `AtbBattle.get_danger()` tell, and what the AI weighs where it stands
## (`GridBattleAi`).

## How many living units of `battle` hostile to `faction` could strike each
## open cell on their next turns: the cells a damaging action of theirs ready
## by then reaches, area and all, from a cell they could walk to
## (`BattleUnitData.move`) without passing the units hostile to them; a cell
## none reaches is left out. `moving` counts as gone from its cell, so they
## may walk through it.
static func count(battle: AtbBattle, faction: StringName, moving: GridUnit = null) -> Dictionary[Vector2i, int]:
	var threats: Dictionary[Vector2i, int] = {}
	for foe: GridUnit in battle.units:
		if not foe.is_alive() or not FactionData.are_hostile(foe.faction, faction):
			continue
		var walls := battle.foe_cells(foe)
		if moving != null:
			walls.erase(moving.cell)
		var froms: Array[Vector2i] = []
		for from: Vector2i in battle.grid.walk(foe.cell, foe.data.move, walls):
			var there := battle.get_unit_at(from)
			if there == null or there == foe or there == moving:
				froms.append(from)
		var struck: Dictionary[Vector2i, bool] = {}
		for action: BattleActionData in foe.data.get_actions():
			if action.effect != BattleActionData.Effect.DAMAGE or foe.turns_to_ready(action) > 1:
				continue
			var aims: Dictionary[Vector2i, bool] = {}
			for from: Vector2i in froms:
				for aim: Vector2i in battle.grid.cells_in_range(from, action.min_range, action.max_range):
					aims[aim] = true
			for aim: Vector2i in aims:
				for cell: Vector2i in battle.grid.cells_in_range(aim, 0, action.area):
					if battle.grid.is_open(cell):
						struck[cell] = true
		for cell: Vector2i in struck:
			threats[cell] = threats.get(cell, 0) + 1
	return threats
