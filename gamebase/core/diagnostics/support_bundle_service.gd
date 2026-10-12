class_name SupportBundleService
extends Node

signal bundle_created(path: String)
signal bundle_failed(message: String)

const BUNDLE_SCHEMA := 1
const MAX_LOG_FILES := 5
const MAX_LOG_BYTES := 2 * 1024 * 1024

var output_directory := "user://support"
## Where the game writes its logs and the file name they start with, both from
## the project's `debug/file_logging/log_path`.
var logs_directory := ""
var log_prefix := ""

func _init() -> void:
	var log_path := String(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	logs_directory = log_path.get_base_dir()
	log_prefix = log_path.get_file().get_basename().to_lower()

func is_supported() -> bool:
	return OS.get_name() != "Web"

func create_bundle(custom_output_path: String = "") -> String:
	if not is_supported():
		_fail("Support bundles are unavailable in Web builds.")
		return ""

	var output_path := custom_output_path
	if output_path.is_empty():
		if not _ensure_directory(output_directory):
			_fail("Could not create support directory.")
			return ""
		output_path = output_directory.path_join("%s-support-%s.zip" % [_file_safe_project_name(), _timestamp()])
	else:
		var parent := output_path.get_base_dir()
		if not parent.is_empty() and not _ensure_directory(parent):
			_fail("Could not create support directory.")
			return ""

	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))

	var log_entries := _collect_logs()
	var summary := build_summary()
	var included_logs: Array[Dictionary] = []
	for entry: Dictionary in log_entries:
		included_logs.append({
			"name": String(entry.get("name", "")),
			"included_bytes": mini(int(entry.get("size", 0)), MAX_LOG_BYTES),
		})
	summary["included_logs"] = included_logs

	var packer := ZIPPacker.new()
	var open_error := packer.open(output_path)
	if open_error != OK:
		_fail("Could not create support bundle (%d)." % open_error)
		return ""

	if not _write_text(packer, "support_summary.json", JSON.stringify(summary, "	")):
		packer.close()
		_remove_if_exists(output_path)
		_fail("Could not write support summary.")
		return ""
	if not _write_text(packer, "README.txt", _readme_text()):
		packer.close()
		_remove_if_exists(output_path)
		_fail("Could not write support bundle notes.")
		return ""

	for entry: Dictionary in log_entries:
		var bytes := _read_log_tail(String(entry.get("path", "")))
		if bytes.is_empty():
			continue
		if not _write_bytes(packer, "logs/%s" % String(entry["name"]), bytes):
			packer.close()
			_remove_if_exists(output_path)
			_fail("Could not add diagnostic log.")
			return ""

	var close_error := packer.close()
	if close_error != OK:
		_remove_if_exists(output_path)
		_fail("Could not finalize support bundle (%d)." % close_error)
		return ""

	bundle_created.emit(output_path)
	return output_path

func build_summary() -> Dictionary:
	# The settings as their file holds them, with each binding by name.
	var settings := GameSettings.to_data()
	var controls: Dictionary = {}
	var gamepad: Dictionary = {}
	for action: StringName in GameSettings.get_rebindable_actions():
		controls[String(action)] = GameSettings.get_key_binding_text(action)
		if GameSettings.has_gamepad_binding(action):
			gamepad[String(action)] = GameSettings.get_gamepad_binding_text(action)
	settings["controls"] = controls
	settings["gamepad"] = gamepad

	var slots: Array[Dictionary] = []
	for slot in range(1, GameSaveManager.SLOT_COUNT + 1):
		slots.append(_sanitize_slot_summary(SaveManager.get_slot_summary(slot)))

	return {
		"schema": BUNDLE_SCHEMA,
		"generated_unix": int(Time.get_unix_time_from_system()),
		"runtime": GameDiagnostics.get_runtime_context(),
		"settings": settings,
		"save_slots": slots,
		"privacy": {
			"raw_saves_included": false,
			"raw_settings_file_included": false,
			"absolute_paths_redacted": true,
			"licensed_source_art_included": false,
		},
	}

func get_output_directory_absolute() -> String:
	if not _ensure_directory(output_directory):
		return ""
	return ProjectSettings.globalize_path(output_directory)

func _sanitize_slot_summary(summary: Dictionary) -> Dictionary:
	var result := {
		"slot": int(summary.get("slot", 0)),
		"exists": bool(summary.get("exists", false)),
		"recoverable": bool(summary.get("recoverable", false)),
		"unreadable": bool(summary.get("unreadable", false)),
	}
	if not result["exists"]:
		return result

	for key: String in [
		"recovery_source",
		"version",
		"game_version",
		"engine_version",
		"saved_at_unix",
		"location_id",
		"play_seconds",
		"day",
		"season",
		"day_of_season",
		"minute_of_day",
	]:
		if summary.has(key):
			result[key] = summary[key]
	return result

func _collect_logs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(logs_directory)
	if directory == null:
		return result

	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.to_lower().begins_with(log_prefix) and name.to_lower().ends_with(".log"):
			var path := logs_directory.path_join(name)
			result.append({
				"name": name.get_file(),
				"path": path,
				"size": _file_length(path),
				"modified": FileAccess.get_modified_time(path),
			})
		name = directory.get_next()
	directory.list_dir_end()

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("modified", 0)) > int(b.get("modified", 0))
	)
	if result.size() > MAX_LOG_FILES:
		result.resize(MAX_LOG_FILES)
	return result

func _read_log_tail(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length := file.get_length()
	var start := maxi(length - MAX_LOG_BYTES, 0)
	file.seek(start)
	var bytes := file.get_buffer(length - start)
	file.close()
	if start > 0:
		# The cut can land inside a line or inside a multi-byte character, which
		# would not decode. Keep the tail from the next full line on.
		var line_end := bytes.find(10)
		bytes = bytes.slice(line_end + 1) if line_end >= 0 else PackedByteArray()
	return _sanitize_log_bytes(bytes)

func _file_length(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var length := file.get_length()
	file.close()
	return length

func _sanitize_log_bytes(bytes: PackedByteArray) -> PackedByteArray:
	var text := bytes.get_string_from_utf8()
	var redactions := {
		ProjectSettings.globalize_path("user://"): "<USER_DATA>",
		ProjectSettings.globalize_path("res://"): "<GAME_RES>",
		OS.get_executable_path().get_base_dir(): "<GAME_DIR>",
		OS.get_environment("USERPROFILE"): "<USER_HOME>",
		OS.get_environment("HOME"): "<USER_HOME>",
	}
	for raw_path: Variant in redactions:
		var path := String(raw_path)
		if path.is_empty():
			continue
		var replacement := String(redactions[raw_path])
		text = text.replace(path, replacement)
		text = text.replace(path.replace("\\", "/"), replacement)
	return text.to_utf8_buffer()

func _write_text(packer: ZIPPacker, name: String, value: String) -> bool:
	return _write_bytes(packer, name, value.to_utf8_buffer())

func _write_bytes(packer: ZIPPacker, name: String, bytes: PackedByteArray) -> bool:
	if packer.start_file(name) != OK:
		return false
	if packer.write_file(bytes) != OK:
		packer.close_file()
		return false
	return packer.close_file() == OK

func _ensure_directory(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute) == OK

func _timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0)),
	]

func _readme_text() -> String:
	return """GameBase Support Bundle

This archive is created only when you explicitly request it in Settings.

Included:
- support_summary.json: GameBase/Godot version, locale, accessibility/audio/settings summary, key bindings, and save-slot summaries.
- logs/: up to five recent GameBase log files, capped at 2 MiB per file. Known user/project/executable absolute paths are redacted before packaging.

Not included:
- raw savegame JSON/temp/backup files
- raw settings.json
- purchased/local licensed source art
- absolute user filesystem paths
- account credentials or device identifiers

If support later asks for a raw save file, share that separately only when you choose to do so.
"""

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	push_warning(message)
	bundle_failed.emit(message)

func _file_safe_project_name() -> String:
	var regex := RegEx.create_from_string("[^A-Za-z0-9_-]+")
	var name := regex.sub(String(ProjectSettings.get_setting("application/config/name", "")), "", true)
	return name if not name.is_empty() else "game"
