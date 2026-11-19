class_name GameSaveManager
extends Node

## Writes and restores the game in save slots.
##
## A game has as many slots as its definition sets (`get_slot_count()`). Each
## slot keeps the player's save and an autosave of its own (`AutoSave` writes
## it), so an autosave never replaces what the player saved: a slot continues
## from the newer of the two (`SaveKind.LATEST`), and the pause menu loads the
## player's own save. A load leaves the slot going on from the save it loaded:
## the other one, when newer, is deleted.
##
## A save holds a header (format version, build, slot, time) and one
## dictionary per registered `SaveSection`, among them the core's `place`:
## where the game was, a location, and where the player stood in it when a
## player walks the world. A game with no one walking it (cards, a visual
## novel) saves as well, its place only a location. Only a save of the current
## `SAVE_VERSION` that contains every registered section loads; anything else
## is not a save of this build. Writing goes through a temporary file and keeps
## the previous save as a backup (renamed, not copied), so an interrupted write
## never loses the save: loading takes the newest intact file of the three
## (`SaveFiles` reads each once, until it changes). A load covers the screen
## (`Transition`) while the world holds still, and clears it once the player
## stands where they saved.

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)
signal active_slot_changed(slot: int)

const SAVE_VERSION := 11
## The reason of the lock that holds the world still while a save loads.
const LOAD_LOCK := &"load"

## Which of a slot's saves: the newer of the two, the player's own or the
## autosave.
enum SaveKind { LATEST, MANUAL, AUTO }

## Keys of the save dictionary that belong to the save manager itself, not to a section.
const HEADER_KEYS: Array[String] = [
	"version", "game_version", "engine_version", "slot", "saved_at_unix_msec",
]
## The core's section of where the game was: {"location_id", "player": {"x",
## "y"}}, the player's position only when a player walks the world.
const PLACE_SECTION := &"place"

## Restore orders of the sections the foundation owns. A game places its own
## sections between them (see `.agents/rules/save.md`).
## The place is restored last of all, by opening its location; its order only
## sorts it first in the file.
const SECTION_ORDER_PLACE := 50
const SECTION_ORDER_RANDOM := 100
## `GameSession`'s own section (the time played), registered by the session.
const SECTION_ORDER_SESSION := 150
## `Playthrough`'s section (the playthrough's number).
const SECTION_ORDER_PLAYTHROUGH := 160
const SECTION_ORDER_CLOCK := 300
const SECTION_ORDER_VITALS := 600
const SECTION_ORDER_WORLD := 700

## Where the slots are stored. A test points it at a directory of its own and
## calls `select_slot()` before saving.
var save_directory := "user://saves"
var active_slot := 1
## The files of the active slot's own save (the player's, not the autosave).
var save_path := ""
var temp_path := ""
var backup_path := ""
# Registered by the game (see `register_section`); sections and load steps are
# kept sorted by order. They are static so that every save manager instance,
# including the ones tests create, reads and writes the same set of sections.
static var _sections: Array[SaveSection] = []
static var _load_steps: Array[Dictionary] = []
static var _save_blockers: Array[Callable] = []
static var _slot_details: Array[Dictionary] = []
# Whether a save is being restored; shared like the sections.
static var _restoring := false
# Counts the changes to the registered sections, which decide what is usable.
static var _sections_changed := 0
# Whether this manager is the one restoring a save.
var _restoring_here := false
var _files := SaveFiles.new(_is_snapshot_usable)

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
		_slot_details.clear()

func _register_core_sections() -> void:
	register_section(SaveSection.new(PLACE_SECTION, SECTION_ORDER_PLACE, SavePlace.write, SavePlace.read))
	register_section(SaveSection.new(&"random", SECTION_ORDER_RANDOM,
		GameRandom.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: GameRandom.load_save_data(section)))
	register_section(SaveSection.new(&"clock", SECTION_ORDER_CLOCK,
		WorldClock.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: WorldClock.load_save_data(section)))
	register_section(SaveSection.new(&"vitals", SECTION_ORDER_VITALS,
		Vitals.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Vitals.load_save_data(section)))
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
	_sections_changed += 1

func unregister_section(id: StringName) -> void:
	for index: int in range(_sections.size() - 1, -1, -1):
		if _sections[index].id == id:
			_sections.remove_at(index)
	_sections_changed += 1

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

## Registers `describe`, `func(snapshot: Dictionary) -> String`, which tells
## from a save what the game adds to its slot's summary (`details` of
## `get_slot_summary()`): translated text, or an empty string for nothing.
## The snapshot is a save this build loads, read and never changed. Details
## show by ascending `order`; registering the same id again replaces it.
func register_slot_detail(id: StringName, order: int, describe: Callable) -> void:
	unregister_slot_detail(id)
	_slot_details.append({"id": id, "order": order, "describe": describe})
	_slot_details.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))

func unregister_slot_detail(id: StringName) -> void:
	for index: int in range(_slot_details.size() - 1, -1, -1):
		if _slot_details[index]["id"] == id:
			_slot_details.remove_at(index)

## How many save slots the game has (`GameDefinition.save_slots`).
static func get_slot_count() -> int:
	return GameDefinition.current().save_slots

func select_slot(slot: int) -> void:
	active_slot = clampi(slot, 1, get_slot_count())
	var paths := get_slot_paths(active_slot)
	save_path = String(paths["save"])
	temp_path = String(paths["temp"])
	backup_path = String(paths["backup"])
	active_slot_changed.emit(active_slot)

## The files of `slot`'s own save, or of its autosave: {"save", "temp",
## "backup"}.
func get_slot_paths(slot: int, autosave := false) -> Dictionary:
	var stem := "%s/slot_%d%s" % [save_directory, clampi(slot, 1, get_slot_count()), "_auto" if autosave else ""]
	return {"save": stem + ".json", "temp": stem + ".tmp", "backup": stem + ".bak"}

## Whether a save is being restored: from reading its sections into the
## services until the player stands where they saved. What the services and
## the saved location announce meanwhile is the save coming back, not play
## (`GameTriggers` ignores it).
static func is_restoring() -> bool:
	return _restoring

## Whether `slot` (the active slot when -1) holds a save of `kind` this
## build can load.
func has_save(slot: int = -1, kind := SaveKind.LATEST) -> bool:
	return not _read_slot(slot, kind).is_empty()

## Whether any file of `slot` (the active slot when -1) exists, whether this
## build can load it or not: a save of another version is never replaced
## without asking.
func has_files(slot: int = -1) -> bool:
	return SaveFiles.any_exists(_slot_files(slot))

## What a slot holds, for slot pickers and support bundles: the newer of its
## saves (`autosave` tells which). `exists` is false when the slot has no
## save of this build; `unreadable` is true when it has files all the same (a
## save of another version, or damaged). A save's summary names its location
## (`location_name`, to translate when shown), the seconds played
## (`play_seconds`) and what the game adds (`details`, see
## `register_slot_detail()`).
func get_slot_summary(slot: int) -> Dictionary:
	var resolved := clampi(slot, 1, get_slot_count())
	var candidate := _read_slot(resolved)
	if candidate.is_empty():
		return {"slot": resolved, "exists": false, "recoverable": false, "unreadable": has_files(resolved)}
	var data: Dictionary = candidate["data"]
	var clock: Dictionary = data["clock"]
	var day := maxi(SaveValues.whole_number_or(clock.get("day", 1), 1), 1)
	var source := String(candidate["source"])
	# A save this build loads names a location of its content.
	var location := SavePlace.find_location(data)
	return {
		"slot": resolved,
		"exists": true,
		"unreadable": false,
		"autosave": bool(candidate["autosave"]),
		"recoverable": source != "primary",
		"recovery_source": source,
		"version": SAVE_VERSION,
		"game_version": String(data.get("game_version", "")),
		"engine_version": String(data.get("engine_version", "")),
		"saved_at_unix": _snapshot_timestamp(data) / 1000,
		"location_id": String(location.id),
		"location_name": location.display_name,
		"play_seconds": GameSessionService.read_play_seconds(data),
		"day": day,
		"season": GameCalendar.current().get_season_name(day),
		"day_of_season": GameCalendar.current().get_day_of_season(day),
		"minute_of_day": clampi(SaveValues.whole_number_or(clock.get("minute_of_day", 0), 0), 0, GameClock.MINUTES_PER_DAY - 1),
		"details": _describe_slot(data),
	}

func _describe_slot(data: Dictionary) -> PackedStringArray:
	var details := PackedStringArray()
	for detail: Dictionary in _slot_details:
		var text := String((detail["describe"] as Callable).call(data))
		if not text.is_empty():
			details.append(text)
	return details

## Deletes `slot`'s saves, the player's and the autosave.
func delete_slot(slot: int) -> bool:
	return _files.delete(_slot_files(slot))

## Deletes the active slot's saves, the player's and the autosave.
func delete_save() -> bool:
	return delete_slot(active_slot)

# Quick load asks first, in the pause menu (`PauseMenu`).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()

func get_save_block_reason() -> String:
	if _restoring:
		return tr("Cannot save while a save loads")
	if GameSession.is_starting_new_game():
		return tr("Cannot save while a new game starts")
	if WorldTravel.is_traveling():
		return tr("Cannot save while traveling")
	var scene := get_tree().current_scene
	if scene == null or WorldLocationData.find_for_scene(scene.scene_file_path) == null:
		return tr("Save from a playable location")
	for blocker: Callable in _save_blockers:
		var reason := String(blocker.call())
		if not reason.is_empty():
			return reason
	return ""

## Saves the game in the active slot and says how it went with
## `save_completed`.
func save_game() -> bool:
	var problem := write_save()
	save_completed.emit(problem.is_empty(), tr("Game saved · Slot %d") % active_slot if problem.is_empty() else problem)
	return problem.is_empty()

## Saves the game in the active slot without a word, as the player's save or
## as its autosave: an empty string when it is saved, else why not, in words
## for the player (the log has the details).
func write_save(autosave := false) -> String:
	var block_reason := get_save_block_reason()
	if not block_reason.is_empty():
		return block_reason
	var paths := get_slot_paths(active_slot, autosave)
	var path := String(paths["save"])
	var temp := String(paths["temp"])
	var backup := String(paths["backup"])
	if not _files.write(temp, build_snapshot()):
		return _write_failed("the save", temp)
	# The last intact save becomes the backup before the new one replaces it.
	if not _read_usable(path).is_empty():
		var backup_error := _files.move(path, backup)
		if backup_error != OK:
			return _write_failed("the backup (%s)" % error_string(backup_error), backup)
	var rename_error := _files.move(temp, path)
	if rename_error != OK:
		return _write_failed("the save (%s)" % error_string(rename_error), path)
	return ""

# Logs which file could not be written and tells the player what to check.
func _write_failed(what: String, path: String) -> String:
	push_warning("SaveManager: could not write %s to %s" % [what, path])
	return tr("Couldn't save: the save folder can't be written to. Check that the disk has free space.")

## Loads the active slot's save of `kind` (the newer of its two by default)
## and says how it went with `load_completed`.
func load_game(kind := SaveKind.LATEST) -> bool:
	if _restoring:
		load_completed.emit(false, tr("A save is already loading"))
		return false
	if WorldTravel.is_traveling():
		load_completed.emit(false, tr("Cannot load while traveling"))
		return false
	var candidate := _read_slot(-1, kind)
	if candidate.is_empty():
		load_completed.emit(false, tr("Slot %d has no save to load") % active_slot)
		return false
	var saved: Dictionary = candidate["data"]
	# The services may keep what they read; what was read of the file stays.
	var data := saved.duplicate(true)
	# Whatever the player is doing belongs to the session the save replaces.
	GameSession.end_activities()
	if not await apply_snapshot(data):
		load_completed.emit(false, tr("This save can't be opened: a place it needs is missing from this version"))
		return false
	# The slot goes on from the save loaded: its other save, when newer, was
	# left behind, and Continue must not bring it back.
	var autosave := bool(candidate["autosave"])
	var other := _read_files_of(active_slot, not autosave)
	if not other.is_empty() and _snapshot_timestamp(other["data"]) > _snapshot_timestamp(saved):
		_files.delete(_files_of(active_slot, not autosave))
	var source := String(candidate["source"])
	if source == "primary":
		load_completed.emit(true, (tr("Autosave loaded · Slot %d") if autosave else tr("Game loaded · Slot %d")) % active_slot)
		return true
	# A recovered save becomes the save again. A temp is a save that was
	# interrupted before its commit, so the commit finishes: the previous primary
	# becomes the backup first.
	var paths := get_slot_paths(active_slot, autosave)
	if source == "temp":
		if not _read_usable(String(paths["save"])).is_empty():
			_files.move(String(paths["save"]), String(paths["backup"]))
		_files.move(String(paths["temp"]), String(paths["save"]))
		load_completed.emit(true, tr("Recovered Slot %d from temporary save") % active_slot)
	else:
		_files.write(String(paths["save"]), saved)
		load_completed.emit(true, tr("Recovered Slot %d from backup") % active_slot)
	return true

func build_snapshot() -> Dictionary:
	var snapshot := {
		"version": SAVE_VERSION,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "")),
		"engine_version": String(Engine.get_version_info().get("string", "")),
		"slot": active_slot,
		"saved_at_unix_msec": int(Time.get_unix_time_from_system() * 1000.0),
	}
	for section: SaveSection in _sections:
		snapshot[String(section.id)] = section.write.call()
	return snapshot

## Restores `data`, a usable snapshot: every section, then the load steps, then
## the saved location with the player where they stood. The screen covers
## first and the world holds still (`LOAD_LOCK`) while the location loads in
## the background; the screen clears once the player stands there.
func apply_snapshot(data: Dictionary) -> bool:
	var location := SavePlace.find_location(data)
	if location == null or not ResourceLoader.exists(location.scene_path):
		return false
	_restoring = true
	_restoring_here = true
	InputLock.lock(LOAD_LOCK, true)
	# A cutscene's cover is the last scene's, which leaves nothing to uncover it.
	Transition.reset()
	await Transition.cover()
	# The destination loads before any service changes, so a save whose
	# location cannot open leaves the running session untouched.
	var packed := await Transition.load_scene(location.scene_path)
	var restored := false
	if packed != null:
		restored = await _restore(data, location, packed)
	_restoring = false
	_restoring_here = false
	InputLock.unlock(LOAD_LOCK)
	Transition.uncover()
	return restored

func _restore(data: Dictionary, location: WorldLocationData, packed: PackedScene) -> bool:
	# Services are restored before the scene is instantiated: scene components
	# read them in _ready().
	for section: SaveSection in _sections:
		section.read.call(data[String(section.id)], data)
	for step: Dictionary in _load_steps:
		(step["step"] as Callable).call()
	# The loaded scene is no travel's.
	WorldTravel.reset()
	if get_tree().change_scene_to_packed(packed) != OK:
		return false
	await get_tree().scene_changed
	await get_tree().process_frame
	var position: Variant = SavePlace.get_player_position(data)
	if position is Vector2:
		WorldTravel.place_player(position)
	else:
		var spawn := WorldSpawnPoint.find(get_tree(), location.default_spawn_id)
		if spawn != null:
			WorldTravel.place_player(spawn.global_position)
	return true

## The save of `kind` in `slot` (the active slot when -1) as {"data",
## "source": "primary" | "temp" | "backup", "autosave"}, or {} when there is
## none; the newer of the player's save and the autosave for `LATEST`.
func _read_slot(slot: int = -1, kind := SaveKind.LATEST) -> Dictionary:
	var resolved := slot if slot > 0 else active_slot
	var manual := _read_files_of(resolved, false) if kind != SaveKind.AUTO else {}
	var auto := _read_files_of(resolved, true) if kind != SaveKind.MANUAL else {}
	if auto.is_empty() or (not manual.is_empty() and _snapshot_timestamp(manual["data"]) >= _snapshot_timestamp(auto["data"])):
		return manual
	return auto

# The newest intact file of one of `slot`'s saves, as `_read_slot()` tells.
# The primary wins unless an intact temp is newer (a save interrupted after
# writing it); without a primary, the temp wins only when newer than the backup.
func _read_files_of(slot: int, autosave: bool) -> Dictionary:
	var paths := get_slot_paths(slot, autosave)
	var primary := _read_usable(String(paths["save"]))
	var temp := _read_usable(String(paths["temp"]))
	var backup := _read_usable(String(paths["backup"]))
	var temp_is_newest := not temp.is_empty() and _snapshot_timestamp(temp) > _snapshot_timestamp(primary if not primary.is_empty() else backup)
	var found := {}
	if temp_is_newest:
		found = {"data": temp, "source": "temp"}
	elif not primary.is_empty():
		found = {"data": primary, "source": "primary"}
	elif not backup.is_empty():
		found = {"data": backup, "source": "backup"}
	elif not temp.is_empty():
		found = {"data": temp, "source": "temp"}
	if not found.is_empty():
		found["autosave"] = autosave
	return found

# Every file of `slot` (the active slot when -1): both saves' files.
func _slot_files(slot: int) -> PackedStringArray:
	var files := _files_of(slot, false)
	files.append_array(_files_of(slot, true))
	return files

# The files of `slot`'s save of the player's or its autosave.
func _files_of(slot: int, autosave: bool) -> PackedStringArray:
	var paths := get_slot_paths(slot if slot > 0 else active_slot, autosave)
	return PackedStringArray([String(paths["save"]), String(paths["temp"]), String(paths["backup"])])

# The save at `path` when it is one this build loads, else {}: read again only
# when the file, the registered sections or the content changed since.
func _read_usable(path: String) -> Dictionary:
	return _files.read_usable(path, [_sections_changed, ContentRegistry.active.get_instance_id()])

func _snapshot_timestamp(data: Dictionary) -> int:
	return SaveValues.count(data.get("saved_at_unix_msec", 0))

## Whether `data` is a complete save of this build that can be loaded.
func _is_snapshot_usable(data: Dictionary) -> bool:
	if SaveValues.whole_number_or(data.get("version", 0), 0) != SAVE_VERSION:
		return false
	for section: SaveSection in _sections:
		if not data.get(String(section.id)) is Dictionary:
			return false
	var clock: Dictionary = data.get("clock", {}) if data.get("clock") is Dictionary else {}
	if not clock.has("day") or not clock.has("minute_of_day"):
		return false
	var location := SavePlace.find_location(data)
	return location != null and ResourceLoader.exists(location.scene_path)
