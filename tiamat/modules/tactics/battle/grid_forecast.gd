class_name GridForecast
extends RefCounted

## What an action would do in a grid battle (`AtbBattle.forecast()`), told
## before it is taken, so the player sees it while aiming.

## What `unit` taking `action` at `cell` from where it stands in `battle`
## would do: a {"unit": GridUnit, "amount": int, "defeats": bool} for each
## unit it reaches, the health it would take (no more than the unit has) or
## give back (no more than it lacks), and with an action that delays, "delay":
## how far it would set back the gauge of a unit it leaves standing, with one
## that boosts, "boosts": those it would put on such a unit, and with one that
## lays an affliction, "affliction": the `AfflictionData` it would leave on such
## a unit that may take it, and with one that cures, "cures": the afflictions
## it would lift from a unit that has any.
static func of(battle: AtbBattle, unit: GridUnit, action: BattleActionData, cell: Vector2i) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for target: GridUnit in battle.affected_at(unit, action, cell, unit.cell):
		var amount := battle.amount_of(unit, action, target)
		var hit: Dictionary
		if action.effect == BattleActionData.Effect.HEAL:
			hit = {"unit": target, "amount": mini(amount, target.health.maximum - target.health.current), "defeats": false}
		else:
			hit = {"unit": target, "amount": mini(amount, target.health.current), "defeats": amount >= target.health.current}
		if action.delay > 0.0 and action.effect == BattleActionData.Effect.DAMAGE:
			hit["delay"] = 0.0 if hit["defeats"] else battle.delay_of(action, target)
		if not action.boosts.is_empty() and not hit["defeats"]:
			hit["boosts"] = action.boosts
		var affliction := AfflictionData.find(action.affliction_id) if action.effect == BattleActionData.Effect.DAMAGE else null
		if not hit["defeats"] and target.can_be_afflicted(affliction):
			hit["affliction"] = affliction
		if action.effect == BattleActionData.Effect.HEAL and action.cures and not target.afflictions.is_empty():
			hit["cures"] = target.afflictions.get_all()
		hits.append(hit)
	return hits
