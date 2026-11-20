class_name CombatModule
extends GameModule

## Wires the combat module into the core (see `GameModule`): enemies, the
## weapons' tool action, the stats a melee attack and a hit on the player read, a fight that ends
## when the player is taken out of play, and the player's choice of how hard
## hits land on them (`PlayerHurtbox.DAMAGE_TAKEN_OPTION`).

const OPTIONS: Array[String] = [
	"res://tiamat/modules/combat/options/damage_taken.tres",
	"res://tiamat/modules/combat/options/foe_strength.tres",
]

func install() -> void:
	ContentDB.register_kind(EnemyData.KIND, EnemyData)
	ContentDB.register_settings(CombatSettings)
	ItemData.register_tool_action(MeleeAttack.TOOL_ACTION)
	for stat: StringName in [&"attack_damage", &"attack_cost", PlayerHurtbox.INCOMING_DAMAGE_STAT, PlayerHurtbox.MAX_HEALTH_STAT, PlayerHurtbox.LOOT_STAT]:
		GameStats.register_stat(stat)
	GameSession.register_activity_end(FightState.end_fight)

func get_options() -> Array[GameOption]:
	var options: Array[GameOption] = []
	for path: String in OPTIONS:
		options.append(load(path) as GameOption)
	return options
