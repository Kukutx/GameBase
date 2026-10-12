class_name RtsModule
extends GameModule

## Wires the rts module into the core (see `GameModule`): command battles in
## real time on an open field, their units and maps, and the battle's
## commands (`CONTROLS`), which the player can rebind.

## The controls of the battle's commands, in the order of
## `RtsBattleGame.Command`.
const CONTROLS: Array[String] = [
	"res://gamebase/modules/rts/controls/rts_attack_move.tres",
	"res://gamebase/modules/rts/controls/rts_stop.tres",
	"res://gamebase/modules/rts/controls/rts_hold.tres",
	"res://gamebase/modules/rts/controls/rts_select_all.tres",
]

func install() -> void:
	ContentDB.register_kind(RtsUnitData.KIND, RtsUnitData)
	ContentDB.register_kind(RtsMapData.KIND, RtsMapData)
	ContentDB.register_settings(RtsSettings)

func get_controls() -> Array[ControlAction]:
	var controls: Array[ControlAction] = []
	for path: String in CONTROLS:
		controls.append(load(path) as ControlAction)
	return controls
