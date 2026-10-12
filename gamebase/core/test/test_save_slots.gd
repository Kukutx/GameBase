extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TEST_DIRECTORY := "user://test_save_slots"
const LOCATION := &"fixture_meadow"
## A world value the tests save and read back.
const MARK := &"fixture:save_mark"

var _scene_path := TEST_DIRECTORY.path_join("fixture_meadow.tscn")
var _manager: GameSaveManager
var _vitals_snapshot: Dictionary
var _world_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _slot_details: Array[Dictionary]

func before_each() -> void:
	_vitals_snapshot = Vitals.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	# What these tests read of a slot leaves out the lines the game adds.
	_slot_details = GameSaveManager._slot_details.duplicate()
	GameSaveManager._slot_details.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
	assert_eq(ResourceSaver.save(_location_scene(), _scene_path), OK)
	var location := WorldLocationData.new()
	location.id = LOCATION
	location.display_name = "Meadow"
	location.scene_path = _scene_path
	location.default_spawn_id = &"fixture_gate"
	# The game's own entries stay indexed beside the fixture location: loading
	# a save restores every section, and the services of the game's modules
	# keep only what is content.
	ContentFixture.use(self, _game_entries() + [location])
	_manager = GameSaveManager.new()
	_manager.save_directory = TEST_DIRECTORY
	add_child_autofree(_manager)
	_delete_test_slots()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	_delete_test_slots()
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == _scene_path:
		get_tree().unload_current_scene()
	if FileAccess.file_exists(_scene_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_scene_path))
	Vitals.load_save_data(_vitals_snapshot)
	WorldState.load_save_data(_world_snapshot)
	WorldClock.load_save_data(_clock_snapshot)
	GameSaveManager._slot_details = _slot_details

func test_write_save_writes_the_slot_without_emitting_a_status() -> void:
	await _enter_fixture_location()
	WorldState.set_value(&"fixture:ratio", 0.1 + 0.2)
	var emitted := {"count": 0}
	_manager.save_completed.connect(func(_success: bool, _message: String) -> void:
		emitted["count"] = int(emitted["count"]) + 1
	)
	assert_eq(_manager.write_save(), "")
	assert_eq(int(emitted["count"]), 0)
	assert_true(FileAccess.file_exists(_manager.save_path))
	assert_false(FileAccess.file_exists(_manager.temp_path))
	var saved := _read(_manager.save_path)
	assert_eq(int(saved.get("version", 0)), GameSaveManager.SAVE_VERSION)
	assert_eq(String(saved.get("game_version", "")), String(ProjectSettings.get_setting("application/config/version", "")))
	assert_false(String(saved.get("engine_version", "")).is_empty())
	assert_eq(saved["place"], {"location_id": String(LOCATION), "player": {"x": 48.0, "y": 32.0}}, "where the game was, and where the player stood")
	for section_id: String in _manager.get_section_ids():
		assert_true(saved.get(section_id) is Dictionary, "section %s is saved" % section_id)
	assert_eq(saved["world"]["fixture:ratio"], 0.1 + 0.2, "a float comes back with every digit")

func test_each_slot_has_its_own_files_in_the_save_directory() -> void:
	var slot1 := _manager.get_slot_paths(1)
	var slot2 := _manager.get_slot_paths(2)
	assert_eq(String(slot1["save"]), TEST_DIRECTORY + "/slot_1.json")
	assert_eq(String(slot1["temp"]), TEST_DIRECTORY + "/slot_1.tmp")
	assert_eq(String(slot1["backup"]), TEST_DIRECTORY + "/slot_1.bak")
	assert_eq(String(slot2["save"]), TEST_DIRECTORY + "/slot_2.json")
	assert_eq(_manager.get_slot_paths(2, true), {"save": TEST_DIRECTORY + "/slot_2_auto.json", "temp": TEST_DIRECTORY + "/slot_2_auto.tmp", "backup": TEST_DIRECTORY + "/slot_2_auto.bak"}, "the autosave's files are its own")
	_manager.select_slot(2)
	assert_eq(_manager.save_path, String(slot2["save"]))

func test_the_game_sets_how_many_slots_it_has() -> void:
	var definition := GameDefinition.new()
	definition.save_slots = 5
	var count: int = ContentFixture.with_definition(definition, GameSaveManager.get_slot_count)
	assert_eq(count, 5)
	assert_eq(GameDefinition.new().save_slots, 3, "three by default")
	_manager.select_slot(99)
	assert_eq(_manager.active_slot, GameSaveManager.get_slot_count(), "a slot past the last is the last")
	_manager.select_slot(1)

func test_an_autosave_leaves_the_player_s_save_as_it_was() -> void:
	await _enter_fixture_location()
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(), "")
	# Saves are told apart by the millisecond.
	OS.delay_msec(2)
	WorldState.set_value(MARK, 222)
	assert_eq(_manager.write_save(true), "")
	assert_eq(_mark(_read(_manager.save_path)), 111, "the player's save stays")
	assert_false(FileAccess.file_exists(_manager.backup_path), "and keeps no backup of an autosave")
	assert_eq(_mark(_read(String(_manager.get_slot_paths(1, true)["save"]))), 222)
	var summary := _manager.get_slot_summary(1)
	assert_true(bool(summary["autosave"]), "the slot continues from the newer autosave")
	WorldState.set_value(MARK, 999)
	assert_true(await _manager.load_game())
	assert_eq(WorldState.get_int(MARK), 222, "continuing loads the newer of the two")
	assert_true(_manager.has_save(-1, GameSaveManager.SaveKind.MANUAL), "continuing from the newer keeps the older")
	assert_true(await _manager.load_game(GameSaveManager.SaveKind.MANUAL))
	assert_eq(WorldState.get_int(MARK), 111, "the player's own save loads as it was")
	assert_false(_manager.has_save(-1, GameSaveManager.SaveKind.AUTO), "the newer autosave the player went back from is gone")
	assert_false(bool(_manager.get_slot_summary(1)["autosave"]), "so the slot goes on from the save loaded")
	assert_eq(_manager.write_save(true), "")
	assert_true(_manager.delete_save())
	assert_false(_manager.has_files(), "deleting a slot deletes both")

func test_autosave_writes_the_slot_s_autosave() -> void:
	await _enter_fixture_location()
	var directory := SaveManager.save_directory
	var slot := SaveManager.active_slot
	var setting := GameSettings.autosave
	SaveManager.save_directory = TEST_DIRECTORY
	SaveManager.select_slot(2)
	GameSettings.autosave = true
	var service := AutoSaveService.new()
	add_child_autofree(service)
	WorldState.set_value(MARK, 444)
	var saved := service.request_autosave("test")
	SaveManager.save_directory = directory
	SaveManager.select_slot(slot)
	GameSettings.autosave = setting
	assert_true(saved)
	assert_eq(_mark(_read(TEST_DIRECTORY + "/slot_2_auto.json")), 444)
	assert_false(FileAccess.file_exists(TEST_DIRECTORY + "/slot_2.json"), "the player's save is theirs to write")

func test_a_tie_continues_from_the_player_s_save() -> void:
	await _enter_fixture_location()
	WorldState.set_value(MARK, 111)
	var own := _manager.build_snapshot()
	WorldState.set_value(MARK, 222)
	var auto := _manager.build_snapshot()
	auto["saved_at_unix_msec"] = own["saved_at_unix_msec"]
	_write(_manager.save_path, own)
	_write(String(_manager.get_slot_paths(1, true)["save"]), auto)
	assert_eq(_mark((_manager.call("_read_slot") as Dictionary)["data"]), 111)
	assert_false(bool(_manager.get_slot_summary(1)["autosave"]))

func test_a_damaged_save_of_one_kind_leaves_the_slot_to_the_other() -> void:
	await _enter_fixture_location()
	var auto := _manager.get_slot_paths(1, true)
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(), "")
	OS.delay_msec(2)
	WorldState.set_value(MARK, 222)
	assert_eq(_manager.write_save(true), "")
	_damage(String(auto["save"]))
	assert_eq(_mark((_manager.call("_read_slot") as Dictionary)["data"]), 111, "a damaged autosave leaves the player's save")
	assert_false(bool(_manager.get_slot_summary(1)["autosave"]))
	assert_eq(_manager.write_save(true), "")
	_damage(_manager.save_path)
	assert_false(_manager.has_save(-1, GameSaveManager.SaveKind.MANUAL))
	assert_eq(_mark((_manager.call("_read_slot") as Dictionary)["data"]), 222, "a damaged save of the player's leaves the autosave")
	assert_true(bool(_manager.get_slot_summary(1)["autosave"]))

func test_an_autosave_recovers_from_its_own_backup_and_temp() -> void:
	await _enter_fixture_location()
	var auto := _manager.get_slot_paths(1, true)
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(true), "")
	WorldState.set_value(MARK, 222)
	assert_eq(_manager.write_save(true), "")
	assert_eq(_mark(_read(String(auto["backup"]))), 111)
	_damage(String(auto["save"]))
	WorldState.set_value(MARK, 999)
	assert_true(await _manager.load_game())
	assert_eq(WorldState.get_int(MARK), 111, "a damaged autosave falls back to its own backup")
	assert_eq(_mark(_read(String(auto["save"]))), 111, "which becomes the autosave again")
	WorldState.set_value(MARK, 333)
	var temp := _manager.build_snapshot()
	temp["saved_at_unix_msec"] = int(_read(String(auto["save"]))["saved_at_unix_msec"]) + 100
	_write(String(auto["temp"]), temp)
	WorldState.set_value(MARK, 999)
	assert_true(await _manager.load_game(GameSaveManager.SaveKind.AUTO))
	assert_eq(WorldState.get_int(MARK), 333, "an interrupted autosave finishes")
	assert_eq(_mark(_read(String(auto["save"]))), 333)
	assert_eq(_mark(_read(String(auto["backup"]))), 111)
	assert_false(FileAccess.file_exists(String(auto["temp"])))
	for path: String in [_manager.save_path, _manager.temp_path, _manager.backup_path]:
		assert_false(FileAccess.file_exists(path), "the player's own files stay untouched: %s" % path)

func test_the_core_sections_outlive_the_save_manager_that_registered_them() -> void:
	await _enter_fixture_location()
	var other := GameSaveManager.new()
	add_child(other)
	other.free()
	assert_eq(_manager.build_snapshot()["place"], {"location_id": String(LOCATION), "player": {"x": 48.0, "y": 32.0}})

func test_slot_summary_describes_the_save() -> void:
	await _enter_fixture_location()
	_manager.select_slot(2)
	WorldClock.set_time(68, 600)
	assert_eq(_manager.write_save(), "")
	var summary := _manager.get_slot_summary(2)
	assert_true(bool(summary["exists"]))
	assert_false(bool(summary["recoverable"]))
	assert_eq(String(summary["recovery_source"]), "primary")
	assert_eq(int(summary["version"]), GameSaveManager.SAVE_VERSION)
	assert_eq(String(summary["location_id"]), String(LOCATION))
	assert_eq(int(summary["day"]), 68)
	assert_eq(String(summary["season"]), GameCalendar.current().get_season_name(68))
	assert_eq(int(summary["minute_of_day"]), 600)
	assert_eq(String(summary["location_name"]), "Meadow")
	assert_eq(int(summary["play_seconds"]), GameSession.get_play_seconds())
	assert_eq(Array(summary["details"]), [])
	assert_false(bool(_manager.get_slot_summary(3)["exists"]))

func test_a_slot_summary_reads_the_time_played_and_what_the_game_adds() -> void:
	await _enter_fixture_location()
	assert_eq(_manager.write_save(), "")
	var saved := _read(_manager.save_path)
	saved[String(GameSessionService.SAVE_SECTION)] = {"play_seconds": 3725.0}
	_write(_manager.save_path, saved)
	_manager.register_slot_detail(&"fixture_mark", 20, func(snapshot: Dictionary) -> String: return "Mark %d" % _mark(snapshot))
	_manager.register_slot_detail(&"fixture_place", 10, func(snapshot: Dictionary) -> String: return String(snapshot["place"]["location_id"]))
	_manager.register_slot_detail(&"fixture_nothing", 15, func(_snapshot: Dictionary) -> String: return "")
	var summary := _manager.get_slot_summary(_manager.active_slot)
	assert_eq(int(summary["play_seconds"]), 3725, "the time played comes back as whole seconds")
	assert_eq(Array(summary["details"]), [String(LOCATION), "Mark %d" % WorldState.get_int(MARK)], "by order, without the empty ones")
	saved[String(GameSessionService.SAVE_SECTION)] = {"play_seconds": 12.5}
	_write(_manager.save_path, saved)
	assert_eq(int(_manager.get_slot_summary(_manager.active_slot)["play_seconds"]), 0, "a damaged value reads as none")

func test_a_save_that_cannot_be_written_says_so_in_words_for_the_player() -> void:
	await _enter_fixture_location()
	# A file stands where the save folder would be.
	var blocked := TEST_DIRECTORY.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("not a folder")
	file.close()
	_manager.save_directory = blocked
	_manager.select_slot(1)
	var results: Array = []
	_manager.save_completed.connect(func(success: bool, message: String) -> void: results.append([success, message]))
	assert_false(_manager.save_game())
	_manager.save_directory = TEST_DIRECTORY
	_manager.select_slot(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked))
	assert_eq(results.size(), 1)
	assert_false(bool(results[0][0]))
	assert_string_contains(String(results[0][1]), "Couldn't save")
	assert_push_warning("could not write the save")

func test_an_autosave_that_cannot_be_written_tells_the_player_why() -> void:
	await _enter_fixture_location()
	var blocked := TEST_DIRECTORY.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("not a folder")
	file.close()
	var save_directory := SaveManager.save_directory
	var active_slot := SaveManager.active_slot
	var autosave := GameSettings.autosave
	GameSettings.autosave = true
	SaveManager.save_directory = blocked
	SaveManager.select_slot(1)
	var service := AutoSaveService.new()
	add_child_autofree(service)
	var toasts: Array[String] = []
	var record := func(message: String) -> void: toasts.append(message)
	GameEvents.toast_requested.connect(record)
	var results: Array = []
	service.autosave_failed.connect(func(reason: String, _problem: String) -> void: results.append(["failed", reason]))
	service.autosave_completed.connect(func(success: bool, reason: String) -> void: results.append([success, reason]))
	assert_false(service.request_autosave("interval"))
	GameEvents.toast_requested.disconnect(record)
	SaveManager.save_directory = save_directory
	SaveManager.select_slot(active_slot)
	GameSettings.autosave = autosave
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked))
	assert_eq(results, [["failed", "interval"], [false, "interval"]])
	assert_eq(toasts.size(), 1)
	assert_string_contains(toasts[0], "Couldn't save")
	assert_push_warning("could not write the save")

func test_a_save_of_another_format_or_without_a_section_is_not_a_save() -> void:
	await _enter_fixture_location()
	var snapshot := _manager.build_snapshot()
	var other_version := snapshot.duplicate(true)
	other_version["version"] = GameSaveManager.SAVE_VERSION + 1
	_write(_manager.save_path, other_version)
	assert_false(_manager.has_save())
	var missing_section := snapshot.duplicate(true)
	missing_section.erase("world")
	_write(_manager.save_path, missing_section)
	assert_false(_manager.has_save())
	var unknown_location := snapshot.duplicate(true)
	unknown_location["place"]["location_id"] = "removed_location"
	_write(_manager.save_path, unknown_location)
	assert_false(_manager.has_save())
	_write(_manager.save_path, snapshot)
	assert_true(_manager.has_save())

func test_a_slot_with_files_this_build_cannot_read_is_unreadable_not_empty() -> void:
	await _enter_fixture_location()
	var snapshot := _manager.build_snapshot()
	snapshot["version"] = GameSaveManager.SAVE_VERSION + 1
	_write(String(_manager.get_slot_paths(2)["save"]), snapshot)
	var summary := _manager.get_slot_summary(2)
	assert_false(bool(summary["exists"]))
	assert_true(bool(summary["unreadable"]))
	assert_false(_manager.has_save(2))
	assert_true(_manager.has_files(2))
	assert_false(bool(_manager.get_slot_summary(3)["unreadable"]), "an empty slot has no files")
	assert_false(_manager.has_files(3))

func test_nothing_saves_and_no_second_load_starts_while_a_save_loads() -> void:
	await _enter_fixture_location()
	assert_eq(_manager.write_save(), "")
	var first := {}
	var loading := func() -> void: first["loaded"] = await _manager.load_game()
	loading.call()
	assert_true(GameSaveManager.is_restoring())
	assert_eq(_manager.get_save_block_reason(), "Cannot save while a save loads")
	assert_ne(_manager.write_save(), "")
	var refusals: Array[String] = []
	_manager.load_completed.connect(func(success: bool, message: String) -> void:
		if not success:
			refusals.append(message)
	)
	assert_false(await _manager.load_game())
	assert_eq(refusals, ["A save is already loading"])
	for frame in range(30):
		if first.has("loaded"):
			break
		await get_tree().process_frame
	assert_true(bool(first.get("loaded", false)), "the first load finishes")

func test_a_snapshot_whose_location_cannot_open_changes_nothing() -> void:
	await _enter_fixture_location()
	var snapshot := _manager.build_snapshot()
	snapshot["place"]["location_id"] = "removed_location"
	(snapshot["world"] as Dictionary)[String(MARK)] = 1
	WorldState.set_value(MARK, 987)
	var scene_before := get_tree().current_scene
	assert_false(await _manager.apply_snapshot(snapshot))
	assert_eq(WorldState.get_int(MARK), 987)
	assert_eq(get_tree().current_scene, scene_before)

func test_saving_keeps_the_previous_save_as_backup_and_a_damaged_save_falls_back_to_it() -> void:
	await _enter_fixture_location()
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(), "")
	assert_false(FileAccess.file_exists(_manager.backup_path))
	WorldState.set_value(MARK, 222)
	assert_eq(_manager.write_save(), "")
	assert_eq(_mark(_read(_manager.save_path)), 222)
	assert_eq(_mark(_read(_manager.backup_path)), 111)
	assert_false(FileAccess.get_file_as_string(_manager.save_path).contains("\n"), "a save is compact")

	var corrupt := FileAccess.open(_manager.save_path, FileAccess.WRITE)
	corrupt.store_string("{ definitely not valid json")
	corrupt.close()
	var recovered := _manager.call("_read_slot") as Dictionary
	assert_eq(String(recovered["source"]), "backup")
	assert_eq(_mark(recovered["data"]), 111)

	# A damaged save is not rotated into the backup.
	WorldState.set_value(MARK, 333)
	assert_eq(_manager.write_save(), "")
	assert_eq(_mark(_read(_manager.save_path)), 333)
	assert_eq(_mark(_read(_manager.backup_path)), 111)

func test_a_slot_is_read_once_until_its_file_changes() -> void:
	await _enter_fixture_location()
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(), "")
	assert_true(_manager.has_save())
	var read_files: Dictionary = (_manager.get("_files") as SaveFiles).get("_read")
	var first: Dictionary = read_files[_manager.save_path]["data"]
	assert_true(_manager.has_save())
	assert_eq(_manager.get_slot_summary(1)["location_id"], String(LOCATION))
	assert_true(is_same(read_files[_manager.save_path]["data"], first), "asked again, the file is not read again")
	# Something outside the game changes the file.
	WorldState.set_value(MARK, 4444)
	var changed := _manager.build_snapshot()
	var file := FileAccess.open(_manager.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(changed))
	file.close()
	assert_eq(_mark((_manager.call("_read_slot") as Dictionary)["data"]), 4444)

func test_loading_a_backup_makes_it_the_save_again() -> void:
	await _enter_fixture_location()
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(), "")
	WorldState.set_value(MARK, 222)
	assert_eq(_manager.write_save(), "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_manager.save_path))
	WorldState.set_value(MARK, 999)
	assert_true(await _manager.load_game())
	assert_eq(WorldState.get_int(MARK), 111)
	assert_eq(_mark(_read(_manager.save_path)), 111)

func test_a_save_is_restoring_and_covered_until_the_player_stands_where_they_saved() -> void:
	await _enter_fixture_location()
	assert_eq(_manager.write_save(), "")
	var seen := {}
	var on_scene_changed := func() -> void:
		seen["restoring"] = GameSaveManager.is_restoring()
		seen["covered"] = Transition.is_covered()
		seen["paused"] = get_tree().paused
	get_tree().scene_changed.connect(on_scene_changed)
	assert_true(await _manager.load_game())
	get_tree().scene_changed.disconnect(on_scene_changed)
	assert_eq(seen, {"restoring": true, "covered": true, "paused": true}, "the saved location's scene loads during the restore, behind the cover, with the world still")
	assert_false(GameSaveManager.is_restoring())
	assert_false(get_tree().paused)
	await Transition.wait_until_clear()
	assert_true(Transition.is_clear())

func test_a_newer_complete_temp_finishes_an_interrupted_save() -> void:
	await _enter_fixture_location()
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(), "")
	var primary_time := int(_read(_manager.save_path)["saved_at_unix_msec"])
	WorldState.set_value(MARK, 222)
	var temp := _manager.build_snapshot()
	# A tie keeps the committed save.
	temp["saved_at_unix_msec"] = primary_time
	_write(_manager.temp_path, temp)
	assert_eq(String((_manager.call("_read_slot") as Dictionary)["source"]), "primary")

	temp["saved_at_unix_msec"] = primary_time + 100
	_write(_manager.temp_path, temp)
	assert_eq(String((_manager.call("_read_slot") as Dictionary)["source"]), "temp")
	WorldState.set_value(MARK, 999)
	assert_true(await _manager.load_game())
	assert_eq(WorldState.get_int(MARK), 222)
	assert_false(FileAccess.file_exists(_manager.temp_path))
	assert_eq(_mark(_read(_manager.save_path)), 222)
	assert_eq(_mark(_read(_manager.backup_path)), 111)

func test_without_a_save_a_temp_wins_only_when_newer_than_the_backup() -> void:
	await _enter_fixture_location()
	WorldState.set_value(MARK, 111)
	assert_eq(_manager.write_save(), "")
	WorldState.set_value(MARK, 222)
	assert_eq(_manager.write_save(), "")
	var backup_time := int(_read(_manager.backup_path)["saved_at_unix_msec"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_manager.save_path))
	WorldState.set_value(MARK, 333)
	var temp := _manager.build_snapshot()
	temp["saved_at_unix_msec"] = backup_time - 1
	_write(_manager.temp_path, temp)
	assert_eq(String((_manager.call("_read_slot") as Dictionary)["source"]), "backup")
	temp["saved_at_unix_msec"] = backup_time + 100
	_write(_manager.temp_path, temp)
	var choice := _manager.call("_read_slot") as Dictionary
	assert_eq(String(choice["source"]), "temp")
	assert_eq(_mark(choice["data"]), 333)

func test_save_guard_rejects_unregistered_scene_and_active_travel() -> void:
	var original_scene := get_tree().current_scene
	var fake_scene := Node2D.new()
	fake_scene.name = "UnregisteredSaveGuardScene"
	get_tree().root.add_child(fake_scene)
	get_tree().current_scene = fake_scene
	assert_eq(_manager.get_save_block_reason(), "Save from a playable location")
	assert_false(_manager.save_game())
	assert_false(FileAccess.file_exists(_manager.save_path))

	var previous_traveling := WorldTravel.is_traveling()
	WorldTravel.set("_traveling", true)
	assert_eq(_manager.get_save_block_reason(), "Cannot save while traveling")
	assert_false(await _manager.load_game())
	WorldTravel.set("_traveling", previous_traveling)
	get_tree().current_scene = original_scene
	fake_scene.queue_free()

func test_a_game_with_no_one_walking_its_world_saves_and_loads_its_place() -> void:
	await _enter_fixture_location()
	var player := get_tree().get_first_node_in_group(&"player")
	player.remove_from_group(&"player")
	WorldState.set_value(MARK, 555)
	assert_eq(_manager.get_save_block_reason(), "", "a card table or a visual novel saves as well")
	assert_eq(_manager.write_save(), "")
	assert_eq(_read(_manager.save_path)["place"], {"location_id": String(LOCATION)}, "a place without a player's position")
	WorldState.set_value(MARK, 0)
	assert_true(await _manager.load_game())
	assert_eq(WorldState.get_int(MARK), 555)

## Opens the fixture location, with the player in it, as the current scene.
func _enter_fixture_location() -> void:
	assert_eq(get_tree().change_scene_to_file(_scene_path), OK)
	await get_tree().scene_changed
	await get_tree().process_frame

## A location scene with the player and one spawn point.
static func _location_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "FixtureMeadow"
	var player := Node2D.new()
	player.name = "Player"
	player.position = Vector2(48, 32)
	player.add_to_group(&"player", true)
	root.add_child(player)
	player.owner = root
	var gate := WorldSpawnPoint.new()
	gate.name = "Gate"
	gate.spawn_id = &"fixture_gate"
	root.add_child(gate)
	gate.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

## Every entry of the running game's content.
static func _game_entries() -> Array:
	var entries: Array = []
	for kind: StringName in ContentDB.get_kinds():
		entries.append_array(ContentDB.get_entries(kind))
	return entries

func _read(path: String) -> Dictionary:
	return SaveFiles._read_dictionary(path)

func _write(path: String, data: Dictionary) -> void:
	assert_true((_manager.get("_files") as SaveFiles).write(path, data))

func _damage(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ definitely not valid json")
	file.close()

func _mark(snapshot: Dictionary) -> int:
	return SaveValues.whole_number_or(WorldState.read_saved(snapshot, MARK), 0)

func _delete_test_slots() -> void:
	for slot in range(1, GameSaveManager.get_slot_count() + 1):
		_manager.delete_slot(slot)
