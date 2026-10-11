class_name GameProfileService
extends Node

## The player's profile: what they achieved and unlocked across every save of
## the game. Starting a new game, loading a save or deleting a slot leaves it
## as it is. It holds the unlocked achievements (`AchievementData`) and profile
## flags, booleans and counters as `WorldState` holds a world's, and writes
## them to `profile_path` before the next frame after a change.
##
## Content reads and changes it through rule keys: `ACHIEVEMENT_UNLOCKED`,
## `PROFILE_FLAG`, `PROFILE_FLAG_AT_LEAST`, `UNLOCK_ACHIEVEMENT`,
## `SET_PROFILE_FLAG` and `ADD_PROFILE_FLAG` (`GameRules`). A storefront's
## achievements follow `achievement_unlocked`. A change that could not be
## written is written with the next one, or when the game quits.

signal achievement_unlocked(achievement_id: StringName)
signal flag_changed(key: StringName, value: Variant)
## Emitted when the profile file could not be written; the change is kept and
## written again with the next one.
signal write_failed

const DEFAULT_PROFILE_PATH := "user://profile.json"
## The layout of the profile file; a file of another version is not read.
const PROFILE_VERSION := 1

var profile_path := DEFAULT_PROFILE_PATH

# achievement id -> the Unix time it was unlocked
var _achievements: Dictionary[StringName, int] = {}
# key -> bool or int
var _flags: Dictionary[StringName, Variant] = {}
# Changed since the file was last written.
var _changed := false
# A write is waiting for the next frame.
var _write_scheduled := false
# The last write failed; the player was told.
var _failing := false

func _ready() -> void:
	load_profile()

func _exit_tree() -> void:
	write_now()

func is_unlocked(achievement_id: StringName) -> bool:
	return _achievements.has(achievement_id)

## When the achievement was unlocked, as Unix time; 0 while it is locked.
func get_unlocked_time(achievement_id: StringName) -> int:
	return _achievements.get(achievement_id, 0)

## The unlocked achievements' ids, sorted.
func get_unlocked() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_achievements.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids

## Unlocks an achievement of the running game's content; an unlocked one stays
## as it was. False for an id the content does not have.
func unlock(achievement_id: StringName) -> bool:
	var achievement := AchievementData.find(achievement_id)
	if achievement == null:
		return false
	if is_unlocked(achievement_id):
		return true
	_achievements[achievement_id] = int(Time.get_unix_time_from_system())
	_request_write()
	achievement_unlocked.emit(achievement_id)
	GameEvents.toastf("Achievement unlocked: %s", [achievement.display_name])
	return true

func get_bool(key: StringName) -> bool:
	return bool(_flags.get(key, false))

func get_int(key: StringName) -> int:
	var value: Variant = _flags.get(key, 0)
	return int(value) if typeof(value) == TYPE_INT else 0

## Sets a flag to a boolean or an integer.
func set_flag(key: StringName, value: Variant) -> void:
	if key == &"" or (typeof(value) != TYPE_BOOL and typeof(value) != TYPE_INT):
		return
	var old: Variant = _flags.get(key)
	if typeof(old) == typeof(value) and old == value:
		return
	_flags[key] = value
	_request_write()
	flag_changed.emit(key, value)

func add_int(key: StringName, amount: int) -> int:
	set_flag(key, get_int(key) + amount)
	return get_int(key)

## Forgets every achievement and flag, as for a player who starts over.
func reset_profile() -> void:
	_achievements.clear()
	_flags.clear()
	_request_write()

## Reads the profile from `profile_path`; a missing, unreadable or other
## version's file leaves an empty profile.
func load_profile() -> void:
	# Without the profile, the written copy a crash kept from replacing it.
	var path := profile_path if FileAccess.file_exists(profile_path) else profile_path + ".tmp"
	var json := JSON.new()
	var readable := FileAccess.file_exists(path) and json.parse(FileAccess.get_file_as_string(path)) == OK
	load_save_data(json.data if readable and json.data is Dictionary else {})

## Writes what changed since the file was last written now. False when the
## file could not be written: the change is kept for the next write.
func write_now() -> bool:
	if not _changed:
		return true
	var problem := _write_file()
	if problem.is_empty():
		_changed = false
		_failing = false
		return true
	push_warning("GameProfile: %s" % problem)
	if not _failing:
		_failing = true
		write_failed.emit()
		GameEvents.toast("Could not save your achievements")
	return false

# Writes the profile to `profile_path`; what went wrong, or "".
func _write_file() -> String:
	var temp_path := profile_path + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_path.get_base_dir()))
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "could not write '%s' (%d)" % [temp_path, FileAccess.get_open_error()]
	var stored := file.store_string(JSON.stringify(to_save_data(), "\t"))
	file.close()
	if not stored:
		return "could not write '%s'" % temp_path
	# The profile is replaced whole, so a crash never leaves half a file.
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	var renamed := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(profile_path))
	return "" if renamed == OK else "could not replace '%s' (%d)" % [profile_path, renamed]

func to_save_data() -> Dictionary:
	var achievements := {}
	for achievement_id: StringName in _achievements:
		achievements[String(achievement_id)] = _achievements[achievement_id]
	var flags := {}
	for key: StringName in _flags:
		flags[String(key)] = _flags[key]
	return {"profile_version": PROFILE_VERSION, "achievements": achievements, "flags": flags}

## Takes the profile `data` holds (`to_save_data()`), dropping any change not
## yet written. What is not well formed is left out: an achievement the content
## does not have or without the time it was unlocked, a flag without a key or
## whose value is neither a boolean nor a whole number.
func load_save_data(data: Dictionary) -> void:
	_changed = false
	_achievements.clear()
	_flags.clear()
	if SaveValues.whole_number(data.get("profile_version")) != PROFILE_VERSION:
		return
	var achievements: Variant = data.get("achievements", {})
	if achievements is Dictionary:
		for achievement_id: Variant in achievements:
			var time: Variant = SaveValues.whole_number(achievements[achievement_id])
			var id := StringName(str(achievement_id))
			if time != null and int(time) > 0 and AchievementData.find(id) != null:
				_achievements[id] = int(time)
	var flags: Variant = data.get("flags", {})
	if flags is Dictionary:
		for key: Variant in flags:
			var value: Variant = flags[key]
			if str(key).is_empty():
				continue
			if typeof(value) == TYPE_BOOL:
				_flags[StringName(str(key))] = value
			elif SaveValues.whole_number(value) != null:
				_flags[StringName(str(key))] = SaveValues.whole_number(value)

func _request_write() -> void:
	_changed = true
	if not _write_scheduled:
		_write_scheduled = true
		_write_when_idle.call_deferred()

func _write_when_idle() -> void:
	_write_scheduled = false
	write_now()
