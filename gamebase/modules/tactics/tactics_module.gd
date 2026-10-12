class_name TacticsModule
extends GameModule

## Wires the tactics module into the core (see `GameModule`): grid battles in
## active time, their units, actions and maps.

func install() -> void:
	ContentDB.register_kind(BattleActionData.KIND, BattleActionData)
	ContentDB.register_kind(BattleUnitData.KIND, BattleUnitData)
	ContentDB.register_kind(BattleMapData.KIND, BattleMapData)
	ContentDB.register_settings(TacticsSettings)
