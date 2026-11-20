class_name TacticsModule
extends GameModule

## Wires the tactics module into the core (see `GameModule`): grid battles in
## active time, their units, actions and maps, and the player's choice of how
## fast a battle runs (`GridBattleGame.SPEED_OPTION`).

const OPTIONS: Array[String] = [
	"res://tiamat/modules/tactics/options/battle_speed.tres",
	"res://tiamat/modules/tactics/options/foe_strength.tres",
]

func install() -> void:
	ContentDB.register_kind(BattleActionData.KIND, BattleActionData)
	ContentDB.register_kind(BattleUnitData.KIND, BattleUnitData)
	ContentDB.register_kind(BattleMapData.KIND, BattleMapData)
	ContentDB.register_settings(TacticsSettings)

func get_options() -> Array[GameOption]:
	var options: Array[GameOption] = []
	for path: String in OPTIONS:
		options.append(load(path) as GameOption)
	return options
