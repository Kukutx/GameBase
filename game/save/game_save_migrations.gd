class_name GameSaveMigrations
extends SaveMigrationSteps

## This game's save history (see `SaveMigrationSteps`).

const LEGACY_DEFAULT_SCENE := "res://game/world/dev_world.tscn"
const LEGACY_DEFAULT_LOCATION_ID := "starter_town"
const LEGACY_SCENE_LOCATION_IDS := {
	"res://game/world/dev_world.tscn": "starter_town",
	"res://game/world/riverside_town.tscn": "riverside_town",
	"res://game/world/harbor_town.tscn": "harbor_town",
	"res://game/world/home_interior.tscn": "player_home",
	"res://game/world/old_mine.tscn": "old_mine",
}

func upgrade(from_version: int, data: Dictionary) -> void:
	match from_version:
		1:
			_migrate_v1_to_v2(data)
		2:
			_migrate_v2_to_v3(data)
		3:
			_migrate_v3_to_v4(data)
		4:
			_migrate_v4_to_v5(data)
		5:
			_migrate_v5_to_v6(data)
		6:
			_migrate_v6_to_v7(data)
		7:
			_migrate_v7_to_v8(data)

func finish_legacy_upgrade(data: Dictionary, target_version: int) -> void:
	if String(data.get("scene", "")).is_empty():
		data["scene"] = LEGACY_DEFAULT_SCENE
	if target_version >= 8 and String(data.get("location_id", "")).is_empty():
		data["location_id"] = String(LEGACY_SCENE_LOCATION_IDS.get(String(data.get("scene", "")), LEGACY_DEFAULT_LOCATION_ID))

func _migrate_v1_to_v2(data: Dictionary) -> void:
	if not data.has("weather"):
		data["weather"] = {}
	if not data.has("player_state"):
		data["player_state"] = {}
	if not data.has("relationships"):
		data["relationships"] = {}
	if not data.has("quests"):
		data["quests"] = {}
	if not data.has("skills"):
		data["skills"] = {}

func _migrate_v2_to_v3(data: Dictionary) -> void:
	if not data.has("npc_memory"):
		data["npc_memory"] = {"history": {}, "facts": {}}

func _migrate_v3_to_v4(data: Dictionary) -> void:
	if not data.has("fishing"):
		data["fishing"] = {"cast_count": 0}

func _migrate_v4_to_v5(data: Dictionary) -> void:
	var player_state: Dictionary = data.get("player_state", {}) if data.get("player_state", {}) is Dictionary else {}
	player_state["max_health"] = maxi(_safe_int(player_state.get("max_health", 100), 100), 1)
	player_state["health"] = clampi(_safe_int(player_state.get("health", player_state["max_health"]), int(player_state["max_health"])), 0, int(player_state["max_health"]))
	var hotbar: Variant = player_state.get("hotbar", [])
	if hotbar is Array:
		var list: Array = hotbar.duplicate()
		if list.size() >= 5 and String(list[0]) == "hoe" and String(list[1]) == "watering_can" and not list.has("pickaxe") and not list.has("rusty_sword"):
			list = ["hoe", "watering_can", "pickaxe", "rusty_sword", "turnip_seeds", "fishing_rod", "berry", "", ""]
		player_state["hotbar"] = list
	data["player_state"] = player_state

	var inventory: Dictionary = data.get("inventory", {}) if data.get("inventory", {}) is Dictionary else {}
	if not inventory.has("pickaxe"):
		inventory["pickaxe"] = {"quantity": 1, "display_name": "Pickaxe", "max_stack": 1}
	if not inventory.has("rusty_sword"):
		inventory["rusty_sword"] = {"quantity": 1, "display_name": "Rusty Sword", "max_stack": 1}
	data["inventory"] = inventory

	var skills: Dictionary = data.get("skills", {}) if data.get("skills", {}) is Dictionary else {}
	if not skills.has("mining"):
		skills["mining"] = 0
	if not skills.has("combat"):
		skills["combat"] = 0
	data["skills"] = skills

func _migrate_v5_to_v6(data: Dictionary) -> void:
	if data.has("shipping"):
		return
	var clock: Dictionary = data.get("clock", {}) if data.get("clock", {}) is Dictionary else {}
	data["shipping"] = {
		"pending": {},
		"last_day_seen": maxi(_safe_int(clock.get("day", 1), 1), 1),
	}

func _migrate_v6_to_v7(data: Dictionary) -> void:
	if not data.has("buffs"):
		data["buffs"] = {}

func _migrate_v7_to_v8(data: Dictionary) -> void:
	if data.has("location_id"):
		return
	var scene := String(data.get("scene", ""))
	data["location_id"] = String(LEGACY_SCENE_LOCATION_IDS.get(scene, LEGACY_DEFAULT_LOCATION_ID if scene.is_empty() else ""))

func _safe_int(value: Variant, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
