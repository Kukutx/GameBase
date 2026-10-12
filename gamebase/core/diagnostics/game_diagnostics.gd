class_name GameDiagnosticsService
extends Node

## Prints one line of diagnostics to the game's output and log
## (`GAMEBASE_DIAGNOSTIC` and JSON) at startup and when a save, a load, an
## autosave or a travel fails: the game and engine versions, the system, the
## language, the save slot, the day and time, and the location. `SupportBundle`
## puts the same context in its summary.
##
## Other code can add an event of its own with `record()`. The service only
## prints: it sends nothing anywhere and saves nothing.

const DIAGNOSTIC_SCHEMA := 1

func _ready() -> void:
	call_deferred("_connect_runtime_signals")
	call_deferred("record", "startup")

func get_runtime_context() -> Dictionary:
	var location_id := ""
	if is_instance_valid(ContentDB) and get_tree() != null:
		var location := WorldLocationData.find_current(get_tree())
		if location != null:
			location_id = String(location.id)
	return {
		"diagnostic_schema": DIAGNOSTIC_SCHEMA,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "unknown")),
		"engine": Engine.get_version_info().get("string", "unknown"),
		"os": OS.get_name(),
		"locale": TranslationServer.get_locale(),
		"save_schema": GameSaveManager.SAVE_VERSION,
		"active_slot": SaveManager.active_slot if is_instance_valid(SaveManager) else 0,
		"day": WorldClock.day if is_instance_valid(WorldClock) else 0,
		"minute": WorldClock.minute_of_day if is_instance_valid(WorldClock) else 0,
		"location_id": location_id,
	}

func record(event: String, details: String = "") -> void:
	var payload := get_runtime_context()
	payload["event"] = event
	if not details.is_empty():
		payload["details"] = details
	print("GAMEBASE_DIAGNOSTIC ", JSON.stringify(payload))

func _connect_runtime_signals() -> void:
	if is_instance_valid(SaveManager):
		SaveManager.save_completed.connect(_on_save_completed)
		SaveManager.load_completed.connect(_on_load_completed)
	if is_instance_valid(AutoSave):
		AutoSave.autosave_failed.connect(_on_autosave_failed)
	if is_instance_valid(WorldTravel):
		WorldTravel.travel_failed.connect(_on_travel_failed)

func _on_save_completed(success: bool, message: String) -> void:
	if not success:
		record("save_failed", message)

func _on_load_completed(success: bool, message: String) -> void:
	if not success:
		record("load_failed", message)

func _on_autosave_failed(reason: String, problem: String) -> void:
	record("autosave_failed", "%s | %s" % [reason, problem])

func _on_travel_failed(scene_path: String, spawn_id: StringName, reason: String) -> void:
	var details := "%s | spawn=%s | scene=%s" % [reason, String(spawn_id), scene_path.get_file()]
	record("travel_failed", details)
