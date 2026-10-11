class_name GameSaveManager
extends Node

## Writes and restores the game in save slots.
##
## A save holds a header (format version, build, slot, time, location, player
## position) and one dictionary per registered `SaveSection`. Only a save of the
## current `SAVE_VERSION` that contains every registered section loads; anything
## else is not a save of this build. Writing goes through a temporary file and
## keeps the previous save as a backup, so an interrupted write never loses the
## slot: loading takes the newest intact file of the three.

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)
signal active_slot_changed(slot: int)

const SAVE_VERSION := 5
const SLOT_COUNT := 3

## Keys of the save dictionary that belong to the save manager itself, not to a section.
const HEADER_KEYS: Array[String] = [
	"version", "game_version", "engine_version", "slot", "saved_at_unix_msec", "location_id", "player",
]

## Restore orders of the sections the foundation owns. A game places its own
## sections between them (see `.agents/rules/save.md`).
const SECTION_ORDER_RANDOM := 100
const SECTION_ORDER_CLOCK := 300
const SECTION_ORDER_PLAYER_STATE := 600
const SECTION_ORDER_WORLD := 700

## Where the slots are stored. A test points it at a directory of its own and
## calls `select_slot()` before saving.
var save_directory := "user://saves"
var active_slot := 1
var save_path := ""
var temp_path := ""
var backup_path := ""
# Registered by the game (see `register_section`); sections and load steps are
# kept sorted by order. They are static so that every save manager instance,
# including the ones tests create, reads and writes the same set of sections.
static var _sections: Array[SaveSection] = []
static var _load_steps: Array[Dictionary] = []
static var _save_blockers: Array[Callable] = []
# Whether a save is being restored; shared like the sections.
static var _restoring := false
# Whether this manager is the one restoring a save.
var _restoring_here := false

func _ready() -> void:
	_register_core_sections()
	select_slot(active_slot)

func _exit_tree() -> void:
	# A manager freed while it restores never resumes to end the restore.
	if _restoring_here:
		_restoring = false
		_restoring_here = false
	# The registrations hold callables of other autoloads. Release them while
	# those still exist when the autoload itself leaves, instead of when the
	# script's static variables are torn down at engine shutdown.
	if get_parent() == get_tree().root:
		_sections.clear()
		_load_steps.clear()
		_save_blockers.clear()

func _register_core_sections() -> void:
	register_section(SaveSection.new(&"random", SECTION_ORDER_RANDOM,
		GameRandom.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: GameRandom.load_save_data(section)))
	register_section(SaveSection.new(&"clock", SECTION_ORDER_CLOCK,
		WorldClock.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: WorldClock.load_save_data(section)))
	register_section(SaveSection.new(&"player_state", SECTION_ORDER_PLAYER_STATE,
		PlayerState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: PlayerState.load_save_data(section)))
	register_section(SaveSection.new(&"world", SECTION_ORDER_WORLD,
		WorldState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: WorldState.load_save_data(section)))

## Registers the service that owns one section of the save. Registering the same
## id again replaces the earlier registration.
func register_section(section: SaveSection) -> void:
	if section == null or section.id == &"" or HEADER_KEYS.has(String(section.id)):
		push_error("SaveManager: invalid save section id '%s'" % (String(section.id) if section != null else ""))
		return
	unregister_section(section.id)
	_sections.append(section)
	_sections.sort_custom(func(a: SaveSection, b: SaveSection) -> bool: return a.order < b.order)

func unregister_section(id: StringName) -> void:
	for index: int in range(_sections.size() - 1, -1, -1):
		if _sections[index].id == id:
			_sections.remove_at(index)

func get_section_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for section: SaveSection in _sections:
		ids.append(String(section.id))
	return ids

## Registers a step that runs after every section has been restored, before the
## saved scene is opened, for runtime state derived from several sections.
## Lower `order` runs first.
func register_load_step(id: StringName, order: int, step: Callable) -> void:
	for index: int in range(_load_steps.size() - 1, -1, -1):
		if _load_steps[index]["id"] == id:
			_load_steps.remove_at(index)
	_load_steps.append({"id": id, "order": order, "step": step})
	_load_steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))

## Registers `func() -> String` returning a translated reason why the game cannot
## be saved right now, or an empty string.
func register_save_blocker(blocker: Callable) -> void:
	if not _save_blockers.has(blocker):
		_save_blockers.append(blocker)

func select_slot(slot: int) -> void:
	active_slot = clampi(slot, 1, SLOT_COUNT)
	var paths := get_slot_paths(active_slot)
	save_path = String(paths["save"])
	temp_path = String(paths["temp"])
	backup_path = String(paths["backup"])
	active_slot_changed.emit(active_slot)

func get_slot_paths(slot: int) -> Dictionary:
	var stem := "%s/slot_%d" % [save_directory, clampi(slot, 1, SLOT_COUNT)]
	return {"save": stem + ".json", "temp": stem + ".tmp", "backup": stem + ".bak"}

## Whether a save is being restored: from reading its sections into the
## services until the player stands where they saved. What the services and
## the saved location announce meanwhile is the save coming back, not play
## (`GameTriggers` ignores it).
static func is_restoring() -> bool:
	return _restoring

func has_save(slot: int = -1) -> bool:
	return not _read_slot(slot).is_empty()

## What a slot holds, for slot pickers and support bundles. `exists` is false
## when the slot has no save of this build.
func get_slot_summary(slot: int) -> Dictionary:
	var resolved := clampi(slot, 1, SLOT_COUNT)
	var candidate := _read_slot(resolved)
	if candidate.is_empty():
		return {"slot": resolved, "exists": false, "recoverable": false}
	var data: Dictionary = candidate["data"]
	var clock: Dictionary = data["clock"]
	var player_state: Dictionary = data.get("player_state", {})
	var day := maxi(_safe_int(clock.get("day", 1), 1), 1)
	var source := String(candidate["source"])
	return {
		"slot": resolved,
		"exists": true,
		"recoverable": source != "primary",
		"recovery_source": source,
		"version": SAVE_VERSION,
		"game_version": String(data.get("game_version", "")),
		"engine_version": String(data.get("engine_version", "")),
		"saved_at_unix": _snapshot_timestamp(data) / 1000,
		"location_id": String(data.get("location_id", "")),
		"day": day,
		"season": GameCalendar.current().get_season_name(day),
		"day_of_season": GameCalendar.current().get_day_of_season(day),
		"minute_of_day": clampi(_safe_int(clock.get("minute_of_day", 0), 0), 0, GameClock.MINUTES_PER_DAY - 1),
		"money": maxi(_safe_int(player_state.get("money", 0), 0), 0),
	}

func delete_slot(slot: int) -> bool:
	var paths := get_slot_paths(slot)
	return _delete_paths([String(paths["save"]), String(paths["temp"]), String(paths["backup"])])

func delete_save() -> bool:
	return _delete_paths([save_path, temp_path, backup_path])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_game()
		get_viewport().set_input_as_handled()

func get_save_block_reason() -> String:
	if WorldTravel.is_traveling():
		return tr("Cannot save while traveling")
	var scene := get_tree().current_scene
	if scene == null or WorldLocationData.find_for_scene(scene.scene_file_path) == null:
		return tr("Save from a playable location")
	if get_tree().get_first_node_in_group("player") == null:
		return tr("Cannot save without the player")
	for blocker: Callable in _save_blockers:
		var reason := String(blocker.call())
		if not reason.is_empty():
			return reason
	return ""

func save_game() -> bool:
	return _save(true)

func save_game_silent() -> bool:
	return _save(false)

func _save(emit_result: bool) -> bool:
	var block_reason := get_save_block_reason()
	if not block_reason.is_empty():
		_emit_save_result(emit_result, false, block_reason)
		return false
	if not _write_dictionary(temp_path, build_snapshot()):
		_emit_save_result(emit_result, false, tr("Could not write temporary save file"))
		return false
	# The last intact save becomes the backup before the new one replaces it.
	var previous := _read_dictionary(save_path)
	if _is_snapshot_usable(previous) and not _write_dictionary(backup_path, previous):
		_emit_save_result(emit_result, false, tr("Could not create save backup"))
		return false
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if rename_error != OK:
		_emit_save_result(emit_result, false, tr("Could not finalize save file (%d)") % rename_error)
		return false
	_emit_save_result(emit_result, true, tr("Game saved · Slot %d") % active_slot)
	return true

func _emit_save_result(enabled: bool, success: bool, message: String) -> void:
	if enabled:
		save_completed.emit(success, message)

func load_game() -> bool:
	if WorldTravel.is_traveling():
		load_completed.emit(false, tr("Cannot load while traveling"))
		return false
	var candidate := _read_slot()
	if candidate.is_empty():
		load_completed.emit(false, tr("No save file yet"))
		return false
	var data: Dictionary = candidate["data"]
	if not await apply_snapshot(data):
		load_completed.emit(false, tr("Save references an unavailable scene"))
		return false
	var source := String(candidate["source"])
	if source == "primary":
		load_completed.emit(true, tr("Game loaded · Slot %d") % active_slot)
		return true
	# A recovered save becomes the slot's save again. A temp is a save that was
	# interrupted before its commit, so the commit finishes: the previous primary
	# becomes the backup first.
	if source == "temp":
		var previous := _read_usable(save_path)
		if not previous.is_empty():
			_write_dictionary(backup_path, previous)
	if _write_dictionary(save_path, data) and source == "temp":
		_delete_paths([temp_path])
	if source == "temp":
		load_completed.emit(true, tr("Recovered Slot %d from temporary save") % active_slot)
	else:
		load_completed.emit(true, tr("Recovered Slot %d from backup") % active_slot)
	return true

func build_snapshot() -> Dictionary:
	var location := WorldLocationData.find_current(get_tree())
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var snapshot := {
		"version": SAVE_VERSION,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "")),
		"engine_version": String(Engine.get_version_info().get("string", "")),
		"slot": active_slot,
		"saved_at_unix_msec": int(Time.get_unix_time_from_system() * 1000.0),
		"location_id": String(location.id) if location != null else "",
		"player": {"x": player.global_position.x, "y": player.global_position.y} if player != null else {},
	}
	_write_sections(snapshot)
	return snapshot

func _write_sections(snapshot: Dictionary) -> void:
	for section: SaveSection in _sections:
		snapshot[String(section.id)] = section.write.call()

## Restores `data`, a usable snapshot: every section, then the load steps, then
## the saved location with the player where they stood.
func apply_snapshot(data: Dictionary) -> bool:
	# Resolve and load the destination before changing any service, so a save
	# whose location cannot open leaves the running session untouched.
	var location := WorldLocationData.find(StringName(String(data.get("location_id", ""))))
	if location == null or not ResourceLoader.exists(location.scene_path):
		return false
	var packed := ResourceLoader.load(location.scene_path) as PackedScene
	if packed == null:
		return false
	_restoring = true
	_restoring_here = true
	var restored: bool = await _restore(data, location, packed)
	_restoring = false
	_restoring_here = false
	return restored

func _restore(data: Dictionary, location: WorldLocationData, packed: PackedScene) -> bool:
	# Services are restored before the scene is instantiated: scene components
	# read them in _ready().
	for section: SaveSection in _sections:
		section.read.call(data[String(section.id)], data)
	for step: Dictionary in _load_steps:
		(step["step"] as Callable).call()
	if get_tree().change_scene_to_packed(packed) != OK:
		return false
	await get_tree().scene_changed
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var position: Variant = data.get("player", {})
		if position is Dictionary and _is_numeric(position.get("x")) and _is_numeric(position.get("y")):
			player.global_position = Vector2(float(position["x"]), float(position["y"]))
		else:
			_apply_player_spawn(player, location.default_spawn_id)
	return true

func _apply_player_spawn(player: Node2D, spawn_id: StringName) -> void:
	for node: Node in get_tree().get_nodes_in_group("world_spawn_point"):
		var spawn := node as WorldSpawnPoint
		if spawn != null and spawn.spawn_id == spawn_id:
			player.global_position = spawn.global_position
			return

## The newest intact save of `slot` (the active slot when -1) as
## {"data", "source": "primary" | "temp" | "backup"}, or {} when there is none.
## The primary wins unless an intact temp is newer (a save interrupted after
## writing it); without a primary, the temp wins only when newer than the backup.
func _read_slot(slot: int = -1) -> Dictionary:
	var paths := get_slot_paths(slot) if slot > 0 else {"save": save_path, "temp": temp_path, "backup": backup_path}
	var primary := _read_usable(String(paths["save"]))
	var temp := _read_usable(String(paths["temp"]))
	var backup := _read_usable(String(paths["backup"]))
	var temp_is_newest := not temp.is_empty() and _snapshot_timestamp(temp) > _snapshot_timestamp(primary if not primary.is_empty() else backup)
	if temp_is_newest:
		return {"data": temp, "source": "temp"}
	if not primary.is_empty():
		return {"data": primary, "source": "primary"}
	if not backup.is_empty():
		return {"data": backup, "source": "backup"}
	if not temp.is_empty():
		return {"data": temp, "source": "temp"}
	return {}

func _read_usable(path: String) -> Dictionary:
	var data := _read_dictionary(path)
	return data if _is_snapshot_usable(data) else {}

func _snapshot_timestamp(data: Dictionary) -> int:
	return maxi(_safe_int(data.get("saved_at_unix_msec", 0), 0), 0)

## Whether `data` is a complete save of this build that can be loaded.
func _is_snapshot_usable(data: Dictionary) -> bool:
	if _safe_int(data.get("version", 0), 0) != SAVE_VERSION:
		return false
	for section: SaveSection in _sections:
		if not data.get(String(section.id)) is Dictionary:
			return false
	var clock: Dictionary = data.get("clock", {}) if data.get("clock") is Dictionary else {}
	if not clock.has("day") or not clock.has("minute_of_day"):
		return false
	var location := WorldLocationData.find(StringName(String(data.get("location_id", ""))))
	return location != null and ResourceLoader.exists(location.scene_path)

func _safe_int(value: Variant, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _read_dictionary(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}

func _write_dictionary(path: String, data: Dictionary) -> bool:
	if path.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	# Every digit, so a float comes back as it was saved.
	var stored := file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()
	return stored

func _delete_paths(paths: Array[String]) -> bool:
	var ok := true
	for path: String in paths:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
	return ok
