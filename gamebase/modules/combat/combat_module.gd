class_name CombatModule
extends GameModule

## Wires the combat module into the core (see `GameModule`).

func install() -> void:
	ContentDB.register_kind(EnemyData.KIND, EnemyData)
