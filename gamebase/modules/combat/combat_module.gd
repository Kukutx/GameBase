class_name CombatModule
extends GameModule

## Wires the combat module into the core (see `GameModule`): enemies, the
## weapons' tool action and the stats a melee attack reads.

func install() -> void:
	ContentDB.register_kind(EnemyData.KIND, EnemyData)
	ItemData.register_tool_action(MeleeAttack.TOOL_ACTION)
	for stat: StringName in [&"attack_damage", &"attack_energy"]:
		GameStats.register_stat(stat)
