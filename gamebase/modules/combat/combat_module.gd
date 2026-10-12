class_name CombatModule
extends GameModule

## Wires the combat module into the core (see `GameModule`): enemies, the
## weapons' tool action, the stats a melee attack reads, and a fight that ends
## when the player is taken out of play.

func install() -> void:
	ContentDB.register_kind(EnemyData.KIND, EnemyData)
	ContentDB.register_settings(CombatSettings)
	ItemData.register_tool_action(MeleeAttack.TOOL_ACTION)
	for stat: StringName in [&"attack_damage", &"attack_cost"]:
		GameStats.register_stat(stat)
	GameSession.register_activity_end(FightState.end_fight)
