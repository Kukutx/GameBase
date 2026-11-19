class_name CombatSettings
extends ModuleSettings

## What a game sets for the combat module (`GameDefinition.module_settings`):
## which vitals a fight takes and spends, what a defeat costs, and the music
## of a fight.

## The vital hits take (`PlayerHurtbox`); the player is defeated when it runs
## out (`PlayerDefeat`). Empty: hits hurt nothing.
@export var health_vital_id: StringName
## The vital a swing spends (`MeleeAttack.cost`); empty: swings are free.
@export var attack_vital_id: StringName
## How much of their money, in percent, a defeated player loses (`Wallet`).
@export_range(0, 100) var defeat_money_loss_percent := 0
## The music a fight plays over the location's (`FightState`); empty: the
## location's plays on.
@export var fight_music_cue_id: StringName = &""
## How long after the last creature stops hunting the player the fight ends.
@export_range(0.0, 30.0, 0.5) var fight_calm_seconds := 3.0

## The running game's combat settings.
static func current() -> CombatSettings:
	return GameDefinition.current().get_settings(CombatSettings) as CombatSettings

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := VitalData.find_reference_problems(registry, "health vital", health_vital_id)
	problems.append_array(VitalData.find_reference_problems(registry, "attack vital", attack_vital_id))
	if defeat_money_loss_percent < 0 or defeat_money_loss_percent > 100:
		problems.append("defeat money loss %d is not a percentage" % defeat_money_loss_percent)
	problems.append_array(AudioCueData.find_reference_problems(registry, "the fight music", fight_music_cue_id, AudioCueData.CueType.MUSIC))
	if fight_calm_seconds < 0.0:
		problems.append("a fight calms down in negative time")
	return problems
