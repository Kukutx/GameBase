class_name RtsModule
extends GameModule

## Wires the rts module into the core (see `GameModule`): command battles in
## real time on an open field, their units and maps, the battle's commands
## (`CONTROLS`), which the player can rebind, and the player's choice of how
## fast a battle runs (`RtsBattleGame.SPEED_OPTION`).

## The controls of the battle's commands, in the order of
## `RtsBattleGame.Command`.
const CONTROLS: Array[String] = [
	"res://tiamat/modules/rts/controls/rts_attack_move.tres",
	"res://tiamat/modules/rts/controls/rts_stop.tres",
	"res://tiamat/modules/rts/controls/rts_hold.tres",
	"res://tiamat/modules/rts/controls/rts_select_all.tres",
]
const OPTIONS: Array[String] = [
	"res://tiamat/modules/rts/options/battle_speed.tres",
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

func get_options() -> Array[GameOption]:
	var options: Array[GameOption] = []
	for path: String in OPTIONS:
		options.append(load(path) as GameOption)
	return options
