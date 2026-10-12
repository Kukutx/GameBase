class_name CombatSettings
extends ModuleSettings

## What a game sets for the combat module (`GameDefinition.module_settings`):
## which vitals a fight takes and spends, and what a defeat costs.

## The vital hits take (`PlayerHurtbox`); the player is defeated when it runs
## out (`PlayerDefeat`). Empty: hits hurt nothing.
@export var health_vital_id: StringName
## The vital a swing spends (`MeleeAttack.cost`); empty: swings are free.
@export var attack_vital_id: StringName
## How much of their money, in percent, a defeated player loses (`Wallet`).
@export_range(0, 100) var defeat_money_loss_percent := 0

## The running game's combat settings.
static func current() -> CombatSettings:
	return GameDefinition.current().get_settings(CombatSettings) as CombatSettings

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := VitalData.find_reference_problems(registry, "health vital", health_vital_id)
	problems.append_array(VitalData.find_reference_problems(registry, "attack vital", attack_vital_id))
	if defeat_money_loss_percent < 0 or defeat_money_loss_percent > 100:
		problems.append("defeat money loss %d is not a percentage" % defeat_money_loss_percent)
	return problems
