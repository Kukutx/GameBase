class_name RtsModule
extends GameModule

## Wires the rts module into the core (see `GameModule`): command battles in
## real time on an open field, their units and maps.

func install() -> void:
	ContentDB.register_kind(RtsUnitData.KIND, RtsUnitData)
	ContentDB.register_kind(RtsMapData.KIND, RtsMapData)
	ContentDB.register_settings(RtsSettings)
