extends GutTest

const TEST_DIRECTORY := "user://test_save_slots"
const STARTER_SCENE := "res://game/world/dev_world.tscn"

var _manager: GameSaveManager
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _clock_day: int
var _clock_minute: int

func before_each() -> void:
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_manager = GameSaveManager.new()
	_manager.save_directory = TEST_DIRECTORY
	add_child_autofree(_manager)
	_delete_test_slots()

func after_each() -> void:
	_delete_test_slots()
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)

func test_silent_save_writes_the_slot_without_emitting_a_status() -> void:
	await _enter_starter_town()
	var emitted := {"count": 0}
	_manager.save_completed.connect(func(_success: bool, _message: String) -> void:
		emitted["count"] = int(emitted["count"]) + 1
	)
	assert_true(_manager.save_game_silent())
	assert_eq(int(emitted["count"]), 0)
	assert_true(FileAccess.file_exists(_manager.save_path))
	assert_false(FileAccess.file_exists(_manager.temp_path))
	var saved := _read(_manager.save_path)
	assert_eq(int(saved.get("version", 0)), GameSaveManager.SAVE_VERSION)
	assert_eq(String(saved.get("game_version", "")), String(ProjectSettings.get_setting("application/config/version", "")))
	assert_false(String(saved.get("engine_version", "")).is_empty())
	assert_eq(String(saved.get("location_id", "")), "starter_town")
	for section_id: String in _manager.get_section_ids():
		assert_true(saved.get(section_id) is Dictionary, "section %s is saved" % section_id)

func test_each_slot_has_its_own_files_in_the_save_directory() -> void:
	var slot1 := _manager.get_slot_paths(1)
	var slot2 := _manager.get_slot_paths(2)
	assert_eq(String(slot1["save"]), TEST_DIRECTORY + "/slot_1.json")
	assert_eq(String(slot1["temp"]), TEST_DIRECTORY + "/slot_1.tmp")
	assert_eq(String(slot1["backup"]), TEST_DIRECTORY + "/slot_1.bak")
	assert_eq(String(slot2["save"]), TEST_DIRECTORY + "/slot_2.json")
	_manager.select_slot(2)
	assert_eq(_manager.save_path, String(slot2["save"]))

func test_slot_summary_describes_the_save() -> void:
	await _enter_starter_town()
	_manager.select_slot(2)
	PlayerState.money = 4321
	WorldClock.set_time(68, 600)
	assert_true(_manager.save_game_silent())
	var summary := _manager.get_slot_summary(2)
	assert_true(bool(summary["exists"]))
	assert_false(bool(summary["recoverable"]))
	assert_eq(String(summary["recovery_source"]), "primary")
	assert_eq(int(summary["version"]), GameSaveManager.SAVE_VERSION)
	assert_eq(String(summary["location_id"]), "starter_town")
	assert_eq(int(summary["day"]), 68)
	assert_eq(String(summary["season"]), GameClock.get_season_name_for_day(68))
	assert_eq(int(summary["minute_of_day"]), 600)
	assert_eq(int(summary["money"]), 4321)
	assert_false(bool(_manager.get_slot_summary(3)["exists"]))

func test_a_save_of_another_format_or_without_a_section_is_not_a_save() -> void:
	await _enter_starter_town()
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
	unknown_location["location_id"] = "removed_location"
	_write(_manager.save_path, unknown_location)
	assert_false(_manager.has_save())
	_write(_manager.save_path, snapshot)
	assert_true(_manager.has_save())

func test_a_snapshot_whose_location_cannot_open_changes_nothing() -> void:
	await _enter_starter_town()
	var snapshot := _manager.build_snapshot()
	snapshot["location_id"] = "removed_location"
	(snapshot["player_state"] as Dictionary)["money"] = 1
	PlayerState.money = 987
	var scene_before := get_tree().current_scene
	assert_false(await _manager.apply_snapshot(snapshot))
	assert_eq(PlayerState.money, 987)
	assert_eq(get_tree().current_scene, scene_before)

func test_saving_keeps_the_previous_save_as_backup_and_a_damaged_save_falls_back_to_it() -> void:
	await _enter_starter_town()
	PlayerState.money = 111
	assert_true(_manager.save_game_silent())
	assert_false(FileAccess.file_exists(_manager.backup_path))
	PlayerState.money = 222
	assert_true(_manager.save_game_silent())
	assert_eq(_money(_read(_manager.save_path)), 222)
	assert_eq(_money(_read(_manager.backup_path)), 111)

	var corrupt := FileAccess.open(_manager.save_path, FileAccess.WRITE)
	corrupt.store_string("{ definitely not valid json")
	corrupt.close()
	var recovered := _manager.call("_read_slot") as Dictionary
	assert_eq(String(recovered["source"]), "backup")
	assert_eq(_money(recovered["data"]), 111)

	# A damaged save is not rotated into the backup.
	PlayerState.money = 333
	assert_true(_manager.save_game_silent())
	assert_eq(_money(_read(_manager.save_path)), 333)
	assert_eq(_money(_read(_manager.backup_path)), 111)

func test_loading_a_backup_makes_it_the_save_again() -> void:
	await _enter_starter_town()
	PlayerState.money = 111
	assert_true(_manager.save_game_silent())
	PlayerState.money = 222
	assert_true(_manager.save_game_silent())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_manager.save_path))
	PlayerState.money = 999
	assert_true(await _manager.load_game())
	assert_eq(PlayerState.money, 111)
	assert_eq(_money(_read(_manager.save_path)), 111)

func test_a_newer_complete_temp_finishes_an_interrupted_save() -> void:
	await _enter_starter_town()
	PlayerState.money = 111
	assert_true(_manager.save_game_silent())
	var primary_time := int(_read(_manager.save_path)["saved_at_unix_msec"])
	PlayerState.money = 222
	var temp := _manager.build_snapshot()
	# A tie keeps the committed save.
	temp["saved_at_unix_msec"] = primary_time
	_write(_manager.temp_path, temp)
	assert_eq(String((_manager.call("_read_slot") as Dictionary)["source"]), "primary")

	temp["saved_at_unix_msec"] = primary_time + 100
	_write(_manager.temp_path, temp)
	assert_eq(String((_manager.call("_read_slot") as Dictionary)["source"]), "temp")
	PlayerState.money = 999
	assert_true(await _manager.load_game())
	assert_eq(PlayerState.money, 222)
	assert_false(FileAccess.file_exists(_manager.temp_path))
	assert_eq(_money(_read(_manager.save_path)), 222)
	assert_eq(_money(_read(_manager.backup_path)), 111)

func test_without_a_save_a_temp_wins_only_when_newer_than_the_backup() -> void:
	await _enter_starter_town()
	PlayerState.money = 111
	assert_true(_manager.save_game_silent())
	PlayerState.money = 222
	assert_true(_manager.save_game_silent())
	var backup_time := int(_read(_manager.backup_path)["saved_at_unix_msec"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_manager.save_path))
	PlayerState.money = 333
	var temp := _manager.build_snapshot()
	temp["saved_at_unix_msec"] = backup_time - 1
	_write(_manager.temp_path, temp)
	assert_eq(String((_manager.call("_read_slot") as Dictionary)["source"]), "backup")
	temp["saved_at_unix_msec"] = backup_time + 100
	_write(_manager.temp_path, temp)
	var choice := _manager.call("_read_slot") as Dictionary
	assert_eq(String(choice["source"]), "temp")
	assert_eq(_money(choice["data"]), 333)

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

func test_title_screen_shows_the_slot_summary() -> void:
	var scene := load("res://game/ui/title_screen.tscn") as PackedScene
	var title := scene.instantiate()
	autofree(title)
	assert_not_null(title.get_node_or_null("Center/Menu/SaveSlot"))
	assert_not_null(title.get_node_or_null("Center/Menu/SlotInfo"))
	assert_not_null(title.get_node_or_null("Center/Menu/DeleteSave"))
	assert_not_null(title.get_node_or_null("ConfirmDelete"))
	var text := String(title.call("_format_slot_summary", {
		"season": "Autumn",
		"day_of_season": 12,
		"day": 68,
		"minute_of_day": 600,
		"money": 4321,
		"recoverable": true,
		"recovery_source": "backup",
	}))
	assert_eq(text, "Autumn 12 · Day 68 · 10:00 · 4321g · backup available")

func _enter_starter_town() -> void:
	WorldState.set_value(GameSession.NEW_GAME_FLAG, true)
	assert_eq(get_tree().change_scene_to_file(STARTER_SCENE), OK)
	await get_tree().scene_changed
	await get_tree().process_frame

func _read(path: String) -> Dictionary:
	return _manager.call("_read_dictionary", path) as Dictionary

func _write(path: String, data: Dictionary) -> void:
	assert_true(bool(_manager.call("_write_dictionary", path, data)))

func _money(snapshot: Dictionary) -> int:
	return int((snapshot["player_state"] as Dictionary)["money"])

func _delete_test_slots() -> void:
	for slot in range(1, GameSaveManager.SLOT_COUNT + 1):
		_manager.delete_slot(slot)
