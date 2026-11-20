class_name GridForecast
extends RefCounted

## What an action would do in a grid battle (`AtbBattle.forecast()`), told
## before it is taken, so the player sees it while aiming.

## What `unit` taking `action` at `cell` from where it stands in `battle`
## would do: a {"unit": GridUnit, "amount": int, "defeats": bool} for each
## unit it reaches, the health it would take (no more than the unit has) or
## give back (no more than it lacks), and with an action that delays, "delay":
## how far it would set back the gauge of a unit it leaves standing, and with
## one that boosts, "boosts": those it would put on such a unit.
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
		hits.append(hit)
	return hits
