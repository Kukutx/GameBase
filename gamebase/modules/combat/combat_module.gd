class_name CombatModule
extends GameModule

## Wires the combat module into the core (see `GameModule`): enemies and
## factions, the weapons' tool action and the stats a melee attack reads.

func install() -> void:
	ContentDB.register_kind(EnemyData.KIND, EnemyData)
	ContentDB.register_kind(FactionData.KIND, FactionData)
	ContentDB.register_settings(CombatSettings)
	ItemData.register_tool_action(MeleeAttack.TOOL_ACTION)
	for stat: StringName in [&"attack_damage", &"attack_cost"]:
		GameStats.register_stat(stat)
