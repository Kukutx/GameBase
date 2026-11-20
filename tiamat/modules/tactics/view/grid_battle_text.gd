class_name GridBattleText
extends RefCounted

## What the side of a grid battle (`GridBattleGame`) tells in words, in the
## player's language, a line each: of a unit, its name, health and stats, the
## boosts on it and how many turns they hold (`GridUnit.get_boost()`), the
## afflictions on it with the seconds each lasts yet (`Afflictions.describe()`)
## and, of a leader, that its side flees once it falls (`describe_unit()`); of
## a cell, the cover, rough ground or goal it is (`describe_cell()`); and what
## an action would do to each unit it reaches (`describe_forecast()`). Another
## view of a grid battle can tell the same.

## The lines of `unit`: "Knight", "HP 12/20", "Attack 6 · Defense 2 · Move
## 3", then its boosts, afflictions and leadership when it has any.
func describe_unit(unit: GridUnit) -> PackedStringArray:
	var lines := PackedStringArray([
		tr(unit.data.display_name),
		tr("HP %d/%d") % [unit.health.current, unit.health.maximum],
		tr("Attack %d · Defense %d · Move %d") % [unit.get_attack(), unit.get_defense(), unit.data.move],
	])
	var boosts := {GridUnit.ATTACK: unit.get_boost(GridUnit.ATTACK), GridUnit.DEFENSE: unit.get_boost(GridUnit.DEFENSE)}
	if boosts.values().any(func(amount: int) -> bool: return amount != 0):
		lines.append(tr("Boosts: %s (turns left: %d)") % [describe_boosts(boosts), unit.get_boost_turns()])
	if not unit.afflictions.is_empty():
		lines.append(tr("Afflicted: %s") % GameText.list(unit.afflictions.describe()))
	if unit.leader:
		lines.append(tr("Leader: their side flees when they fall"))
	return lines

## The lines of `cell` of `battle`: the cover it gives, the steps its rough
## ground takes and which side wins by ending a turn on it.
func describe_cell(battle: AtbBattle, cell: Vector2i) -> PackedStringArray:
	var lines := PackedStringArray()
	if battle.grid.is_cover(cell):
		lines.append(tr("Cover: %d%% less damage") % roundi(battle.grid.cover_reduction * 100.0))
	if battle.grid.is_rough(cell):
		lines.append(tr("Rough ground: %d steps to enter") % battle.grid.rough_cost)
	if battle.goal_cells.has(cell):
		lines.append(tr("Goal: a foe that ends a turn here wins") if FactionData.are_hostile(battle.goal_faction, battle.player_faction) else tr("Goal: end a turn here to win"))
	return lines

## What `action` of `unit` aimed at `cell` would do to each unit it reaches
## (`AtbBattle.forecast()`), a line each: "Raider takes 6 and falls", "Brute
## takes 2, turn delayed", "Swordsman gains Defense +2", "Knight takes 3,
## Poisoned".
func describe_forecast(battle: AtbBattle, unit: GridUnit, action: BattleActionData, cell: Vector2i) -> PackedStringArray:
	var lines := PackedStringArray()
	for hit: Dictionary in battle.forecast(unit, action, cell):
		var target := hit["unit"] as GridUnit
		var target_name := tr(target.data.display_name)
		var line := tr("%s takes %d")
		if action.effect == BattleActionData.Effect.HEAL:
			line = tr("%s regains %d")
		elif bool(hit["defeats"]) and target.leader:
			line = tr("%s takes %d and falls; their side flees")
		elif bool(hit["defeats"]):
			line = tr("%s takes %d and falls")
		elif float(hit.get("delay", 0.0)) > 0.0:
			line = tr("%s takes %d, turn delayed")
		var told := line % [target_name, int(hit["amount"])]
		if hit.has("boosts"):
			var boosted := describe_boosts(hit["boosts"])
			told = tr("%s gains %s") % [target_name, boosted] if action.effect == BattleActionData.Effect.HEAL and int(hit["amount"]) == 0 else GameText.list(PackedStringArray([told, boosted]))
		if hit.has("affliction"):
			told = GameText.list(PackedStringArray([told, tr((hit["affliction"] as AfflictionData).display_name)]))
		if hit.has("cures"):
			var cured := PackedStringArray((hit["cures"] as Array).map(func(affliction: AfflictionData) -> String: return tr(affliction.display_name)))
			told = GameText.list(PackedStringArray([told, tr("cures %s") % GameText.list(cured)]))
		lines.append(told)
	return lines

## The boosts in `boosts` (stat -> amount) that change anything, as the player
## reads them: "Attack +2, Defense -1".
func describe_boosts(boosts: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat: StringName in [GridUnit.ATTACK, GridUnit.DEFENSE]:
		var amount := int(boosts.get(stat, 0))
		if amount != 0:
			var signed := ("+%d" if amount > 0 else "%d") % amount
			parts.append((tr("Attack %s") if stat == GridUnit.ATTACK else tr("Defense %s")) % signed)
	return GameText.list(parts)
