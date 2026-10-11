extends GutTest

const TEST_SAVE := "user://slot_test.json"
const TEST_TEMP := "user://slot_test.tmp"
const TEST_BACKUP := "user://slot_test.bak"

var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _clock_day: int
var _clock_minute: int

func before_each() -> void:
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_cleanup_files()

func after_each() -> void:
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)
	_cleanup_files()

func test_silent_save_uses_atomic_path_without_emitting_manual_save_status() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP
	assert_true(manager.delete_save())
	var emitted := {"count": 0}
	manager.save_completed.connect(func(_success: bool, _message: String) -> void:
		emitted["count"] = int(emitted["count"]) + 1
	)
	assert_true(manager.save_game_silent(true))
	assert_eq(int(emitted["count"]), 0)
	assert_true(FileAccess.file_exists(TEST_SAVE))
	assert_false(FileAccess.file_exists(TEST_TEMP))
	var saved := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	assert_eq(int(saved.get("version", 0)), GameSaveManager.SAVE_VERSION)
	assert_eq(String(saved.get("game_version", "")), String(ProjectSettings.get_setting("application/config/version", "unknown")))
	assert_false(String(saved.get("engine_version", "")).is_empty())

func test_slot_paths_keep_legacy_slot_one_and_isolate_other_slots() -> void:
	var manager := GameSaveManager.new()
	autofree(manager)
	var slot1 := manager.get_slot_paths(1)
	var slot2 := manager.get_slot_paths(2)
	var slot3 := manager.get_slot_paths(3)

	assert_eq(String(slot1["save"]), GameSaveManager.DEFAULT_SAVE_PATH)
	assert_eq(String(slot1["temp"]), GameSaveManager.DEFAULT_TEMP_PATH)
	assert_eq(String(slot1["backup"]), GameSaveManager.DEFAULT_BACKUP_PATH)
	assert_ne(String(slot2["save"]), String(slot1["save"]))
	assert_ne(String(slot3["save"]), String(slot2["save"]))
	assert_true(String(slot2["save"]).ends_with("savegame_slot2.json"))
	assert_true(String(slot3["backup"]).ends_with("savegame_slot3.bak"))

func test_legacy_slot_summary_uses_migrated_defaults_without_hiding_stored_version() -> void:
	var manager := GameSaveManager.new()
	autofree(manager)
	var summary := manager.call("_build_slot_summary", 2, {
		"source": "primary",
		"data": {
			"version": 1,
			"clock": {"day": 3, "minute_of_day": 600},
			"inventory": {},
			"world": {},
		}
	}) as Dictionary
	assert_true(bool(summary.get("exists", false)))
	assert_eq(int(summary.get("version", 0)), 1)
	assert_eq(int(summary.get("day", 0)), 3)
	assert_eq(int(summary.get("minute_of_day", 0)), 600)
	assert_eq(int(summary.get("money", 0)), 500)
	assert_eq(String(summary.get("game_version", "")), "")
	assert_eq(String(summary.get("engine_version", "")), "")

func test_v8_missing_scene_resolves_through_stable_location_id() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	var snapshot := manager.build_snapshot()
	snapshot["scene"] = "res://game/world/removed_riverside_layout.tscn"
	snapshot["location_id"] = "riverside_town"
	assert_true(bool(manager.call("_is_snapshot_usable", snapshot)))
	var destination := manager.call("_resolve_snapshot_destination", snapshot) as Dictionary
	assert_eq(String(destination.get("scene_path", "")), "res://game/world/riverside_town.tscn")
	assert_eq(String(destination.get("location_id", "")), "riverside_town")
	assert_eq(String(destination.get("spawn_id", "")), "from_starter")
	assert_false(bool(destination.get("use_saved_position", true)))
	assert_true(bool(destination.get("remapped", false)))

	var broken := snapshot.duplicate(true)
	broken["location_id"] = "removed_location"
	assert_false(bool(manager.call("_is_snapshot_usable", broken)))

	# Current-format saves cannot use an unrelated but existing scene to bypass an
	# invalid stable Location ID, and apply_snapshot must reject before replacing
	# any live global state.
	var invalid_existing_scene := snapshot.duplicate(true)
	invalid_existing_scene["scene"] = "res://game/ui/title_screen.tscn"
	invalid_existing_scene["location_id"] = "removed_location"
	(invalid_existing_scene["player_state"] as Dictionary)["money"] = 1
	var money_before := 987
	PlayerState.money = money_before
	var scene_before := get_tree().current_scene
	assert_false(bool(manager.call("_is_snapshot_usable", invalid_existing_scene)))
	assert_true(bool((manager.call("_resolve_snapshot_destination", invalid_existing_scene) as Dictionary).get("invalid", false)))
	assert_false(await manager.apply_snapshot(invalid_existing_scene))
	assert_eq(PlayerState.money, money_before)
	assert_eq(get_tree().current_scene, scene_before)

func test_backup_recovery_persists_load_time_reconciliation_into_repaired_primary() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP
	assert_true(manager.delete_save())
	var world_before := WorldState.to_save_data()
	var snapshot := manager.build_snapshot()
	snapshot["scene"] = "res://game/world/dev_world.tscn"
	snapshot["location_id"] = "starter_town"
	snapshot["world"] = {
		String(GameSession.NEW_GAME_FLAG): true,
		"town_projects:state": {
			"starter_garden_restoration": {
				"progress": {"turnip": 3, "carrot": 3, "potato": 3, "wood": 10},
				"completed": false,
				"claimed": false,
				"completed_day": 0,
				"claimed_day": 0,
			},
		},
	}
	assert_true(bool(manager.call("_write_dictionary", TEST_BACKUP, snapshot)))
	assert_true(await manager.load_game())
	assert_true(FileAccess.file_exists(TEST_SAVE))
	var repaired := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var repaired_world := repaired.get("world", {}) as Dictionary
	assert_true(bool(repaired_world.get("project:starter_garden:complete", false)))
	var repaired_projects := repaired_world.get("town_projects:state", {}) as Dictionary
	var repaired_project := repaired_projects.get("starter_garden_restoration", {}) as Dictionary
	assert_true(bool(repaired_project.get("completed", false)))
	assert_true(repaired_project.get("reward_snapshot", {}) is Dictionary)
	assert_false((repaired_project.get("reward_snapshot", {}) as Dictionary).is_empty())
	# The promoted primary must contain the load-time repair itself. Scene-owned
	# systems may legitimately add further WorldState keys on later deferred
	# frames, so byte-for-byte equality with the live dictionary is not required.
	assert_true(bool(repaired_world.get("project:starter_garden:complete", false)))
	WorldState.load_save_data(world_before)

func test_newer_primary_loads_compatible_backup_without_overwriting_newer_save() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP
	assert_true(manager.delete_save())

	WorldClock.set_time(3, 9 * 60)
	PlayerState.money = 111
	assert_true(manager.save_game(true))
	WorldClock.set_time(4, 10 * 60)
	PlayerState.money = 222
	assert_true(manager.save_game(true))

	# Deliberately use a future schema that no longer resembles v8. Downgrade
	# protection must not validate it against this build's section/location rules.
	var future_primary := {
		"version": GameSaveManager.SAVE_VERSION + 1,
		"future_only": {"location": "future_island", "credits": 999},
	}
	assert_true(bool(manager.call("_is_snapshot_usable", future_primary)))
	assert_true(bool(manager.call("_write_dictionary", TEST_SAVE, future_primary)))

	var loadable := manager.call("_read_best_loadable_snapshot", TEST_SAVE, TEST_BACKUP) as Dictionary
	assert_eq(String(loadable.get("source", "")), "backup")
	assert_true(bool(loadable.get("newer_primary_preserved", false)))
	assert_eq(int(((loadable["data"] as Dictionary)["player_state"] as Dictionary)["money"]), 111)

	assert_true(await manager.load_game())
	assert_eq(PlayerState.money, 111)
	var preserved_primary := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	assert_eq(int(preserved_primary.get("version", 0)), GameSaveManager.SAVE_VERSION + 1)
	assert_eq(int((preserved_primary["future_only"] as Dictionary).get("credits", 0)), 999)

	# Continued play on the older build must save back into the compatible backup
	# rather than rotating/overwriting the newer-version primary.
	PlayerState.money = 444
	assert_true(manager.save_game(true))
	preserved_primary = manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var updated_backup := manager.call("_read_dictionary", TEST_BACKUP) as Dictionary
	assert_eq(int(preserved_primary.get("version", 0)), GameSaveManager.SAVE_VERSION + 1)
	assert_eq(int((preserved_primary["future_only"] as Dictionary).get("credits", 0)), 999)
	assert_eq(int(updated_backup.get("version", 0)), GameSaveManager.SAVE_VERSION)
	assert_eq(int((updated_backup["player_state"] as Dictionary)["money"]), 444)
	var updated_loadable := manager.call("_read_best_loadable_snapshot", TEST_SAVE, TEST_BACKUP) as Dictionary
	assert_eq(int(((updated_loadable["data"] as Dictionary)["player_state"] as Dictionary)["money"]), 444)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BACKUP))
	assert_true((manager.call("_read_best_loadable_snapshot", TEST_SAVE, TEST_BACKUP) as Dictionary).is_empty())

func test_save_without_prior_load_preserves_newer_primary_in_compatible_backup() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP
	assert_true(manager.delete_save())
	var future_primary := {
		"version": GameSaveManager.SAVE_VERSION + 1,
		"future_only": {"location": "future_island", "credits": 777},
	}
	assert_true(bool(manager.call("_write_dictionary", TEST_SAVE, future_primary)))
	PlayerState.money = 321
	WorldClock.set_time(6, 12 * 60)
	assert_true(manager.save_game(true))
	var preserved_primary := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var compatible_backup := manager.call("_read_dictionary", TEST_BACKUP) as Dictionary
	assert_eq(int(preserved_primary.get("version", 0)), GameSaveManager.SAVE_VERSION + 1)
	assert_eq(int((preserved_primary["future_only"] as Dictionary).get("credits", 0)), 777)
	assert_eq(int(compatible_backup.get("version", 0)), GameSaveManager.SAVE_VERSION)
	assert_eq(int((compatible_backup["player_state"] as Dictionary).get("money", 0)), 321)
	assert_true(compatible_backup.has("saved_at_unix_msec"))
	assert_false(FileAccess.file_exists(TEST_TEMP))

func test_newer_complete_temp_can_recover_before_old_primary_is_removed() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP
	assert_true(manager.delete_save())
	PlayerState.money = 111
	WorldClock.set_time(3, 9 * 60)
	assert_true(manager.save_game(true))
	var primary := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var primary_time := int(manager.call("_snapshot_timestamp", primary))

	PlayerState.money = 222
	WorldClock.set_time(4, 10 * 60)
	var temp_snapshot := manager.build_snapshot()
	# Exact timestamp ties still prefer the fully committed primary.
	temp_snapshot["saved_at_unix_msec"] = primary_time
	assert_true(bool(manager.call("_write_dictionary", TEST_TEMP, temp_snapshot)))
	var tie_choice := manager.call("_read_best_loadable_slot_snapshot", TEST_SAVE, TEST_TEMP, TEST_BACKUP) as Dictionary
	assert_eq(String(tie_choice.get("source", "")), "primary")

	# The crash window after a complete temp write but before primary removal must
	# recover the strictly newer temp, while preserving the old primary as backup.
	temp_snapshot["saved_at_unix_msec"] = primary_time + 100
	assert_true(bool(manager.call("_write_dictionary", TEST_TEMP, temp_snapshot)))
	var temp_choice := manager.call("_read_best_loadable_slot_snapshot", TEST_SAVE, TEST_TEMP, TEST_BACKUP) as Dictionary
	assert_eq(String(temp_choice.get("source", "")), "temp")
	assert_true(bool(temp_choice.get("replaces_valid_primary", false)))
	assert_true(await manager.load_game())
	assert_eq(PlayerState.money, 222)
	assert_false(FileAccess.file_exists(TEST_TEMP))
	var repaired_primary := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var preserved_backup := manager.call("_read_dictionary", TEST_BACKUP) as Dictionary
	assert_eq(int((repaired_primary["player_state"] as Dictionary).get("money", 0)), 222)
	assert_eq(int((preserved_backup["player_state"] as Dictionary).get("money", 0)), 111)

func test_complete_temp_recovers_interrupted_commit_only_when_newer_than_backup() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP
	assert_true(manager.delete_save())

	WorldClock.set_time(3, 9 * 60)
	PlayerState.money = 111
	assert_true(manager.save_game(true))
	WorldClock.set_time(4, 10 * 60)
	PlayerState.money = 222
	assert_true(manager.save_game(true))
	var backup := manager.call("_read_dictionary", TEST_BACKUP) as Dictionary
	var backup_time := int(manager.call("_snapshot_timestamp", backup))

	WorldClock.set_time(5, 11 * 60)
	PlayerState.money = 333
	var temp_snapshot := manager.build_snapshot()
	# Simulate a stale temp first: with primary unavailable, committed backup wins.
	temp_snapshot["saved_at_unix_msec"] = backup_time - 1
	assert_true(bool(manager.call("_write_dictionary", TEST_TEMP, temp_snapshot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var stale_choice := manager.call("_read_best_loadable_slot_snapshot", TEST_SAVE, TEST_TEMP, TEST_BACKUP) as Dictionary
	assert_eq(String(stale_choice.get("source", "")), "backup")

	# A fully written newer temp represents the crash window after primary removal
	# but before temp->primary rename. It should recover the newest complete state.
	temp_snapshot["saved_at_unix_msec"] = backup_time + 100
	assert_true(bool(manager.call("_write_dictionary", TEST_TEMP, temp_snapshot)))
	var temp_choice := manager.call("_read_best_loadable_slot_snapshot", TEST_SAVE, TEST_TEMP, TEST_BACKUP) as Dictionary
	assert_eq(String(temp_choice.get("source", "")), "temp")
	assert_eq(int(((temp_choice["data"] as Dictionary)["player_state"] as Dictionary)["money"]), 333)

	assert_true(await manager.load_game())
	assert_eq(PlayerState.money, 333)
	assert_false(FileAccess.file_exists(TEST_TEMP))
	var repaired_primary := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var preserved_backup := manager.call("_read_dictionary", TEST_BACKUP) as Dictionary
	assert_eq(int((repaired_primary["player_state"] as Dictionary)["money"]), 333)
	assert_eq(int((preserved_backup["player_state"] as Dictionary)["money"]), 111)

func test_save_rotation_preserves_previous_snapshot_and_corruption_falls_back_to_backup() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP
	assert_true(manager.delete_save())
	WorldClock.set_time(3, 9 * 60)
	PlayerState.money = 111
	assert_true(manager.save_game(true))
	assert_true(FileAccess.file_exists(TEST_SAVE))
	assert_false(FileAccess.file_exists(TEST_BACKUP))

	WorldClock.set_time(4, 10 * 60)
	PlayerState.money = 222
	assert_true(manager.save_game(true))
	assert_true(FileAccess.file_exists(TEST_BACKUP))
	var primary := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var backup := manager.call("_read_dictionary", TEST_BACKUP) as Dictionary
	assert_eq(int((primary["player_state"] as Dictionary)["money"]), 222)
	assert_eq(int((backup["player_state"] as Dictionary)["money"]), 111)
	assert_eq(int((backup["clock"] as Dictionary)["day"]), 3)

	var corrupt := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	assert_not_null(corrupt)
	if corrupt != null:
		corrupt.store_string("{ definitely not valid json")
		corrupt.close()
	var recovered := manager.call("_read_best_snapshot", TEST_SAVE, TEST_BACKUP) as Dictionary
	assert_eq(String(recovered.get("source", "")), "backup")
	assert_eq(int(((recovered["data"] as Dictionary)["player_state"] as Dictionary)["money"]), 111)

	# A syntactically valid but structurally truncated current-version primary is
	# also corruption. It must not win over the complete previous backup.
	var truncated := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	assert_not_null(truncated)
	if truncated != null:
		truncated.store_string(JSON.stringify({
			"version": GameSaveManager.SAVE_VERSION,
			"scene": "",
			"clock": {"day": 9, "minute_of_day": 720},
			"inventory": {},
			"world": {},
		}))
		truncated.close()
	var structural_recovery := manager.call("_read_best_snapshot", TEST_SAVE, TEST_BACKUP) as Dictionary
	assert_eq(String(structural_recovery.get("source", "")), "backup")
	assert_eq(int(((structural_recovery["data"] as Dictionary)["player_state"] as Dictionary)["money"]), 111)

	# Saving over a structurally damaged primary must preserve the last good
	# backup instead of rotating the damaged JSON into the recovery slot.
	PlayerState.money = 333
	WorldClock.set_time(5, 11 * 60)
	assert_true(manager.save_game(true))
	var repaired_primary := manager.call("_read_dictionary", TEST_SAVE) as Dictionary
	var preserved_backup := manager.call("_read_dictionary", TEST_BACKUP) as Dictionary
	assert_eq(int((repaired_primary["player_state"] as Dictionary)["money"]), 333)
	assert_eq(int((preserved_backup["player_state"] as Dictionary)["money"]), 111)

func test_future_only_slot_summary_marks_version_without_inventing_gameplay_data() -> void:
	var manager := GameSaveManager.new()
	autofree(manager)
	var summary := manager.call("_build_slot_summary", 1, {
		"source": "primary",
		"data": {
			"version": GameSaveManager.SAVE_VERSION + 1,
			"future_only": {"credits": 999},
		},
	}) as Dictionary
	assert_true(bool(summary.get("future_version", false)))
	assert_eq(int(summary.get("version", 0)), GameSaveManager.SAVE_VERSION + 1)
	assert_eq(String(summary.get("recovery_source", "")), "primary")

func test_save_guard_rejects_unregistered_scene_and_active_travel() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_path = TEST_SAVE
	manager.temp_path = TEST_TEMP
	manager.backup_path = TEST_BACKUP

	# Earlier save/load tests may legitimately leave the SceneTree on a playable
	# location. Make this guard test independent of execution order by installing
	# a temporary unregistered current scene and restoring the original after.
	var original_scene := get_tree().current_scene
	var fake_scene := Node2D.new()
	fake_scene.name = "UnregisteredSaveGuardScene"
	get_tree().root.add_child(fake_scene)
	get_tree().current_scene = fake_scene
	assert_eq(manager.get_save_block_reason(), "Save from a playable location")
	assert_false(manager.save_game())
	assert_false(FileAccess.file_exists(TEST_SAVE))

	var previous_traveling := WorldTravel.is_traveling()
	WorldTravel.set("_traveling", true)
	assert_eq(manager.get_save_block_reason(), "Cannot save while traveling")
	assert_false(await manager.load_game())
	WorldTravel.set("_traveling", previous_traveling)
	get_tree().current_scene = original_scene
	fake_scene.queue_free()

func test_title_screen_exposes_three_slot_controls() -> void:
	var scene := load("res://game/ui/title_screen.tscn") as PackedScene
	assert_not_null(scene)
	var title := scene.instantiate()
	autofree(title)
	assert_not_null(title.get_node_or_null("Center/Menu/SaveSlot"))
	assert_not_null(title.get_node_or_null("Center/Menu/SlotInfo"))
	assert_not_null(title.get_node_or_null("Center/Menu/DeleteSave"))
	assert_not_null(title.get_node_or_null("ConfirmDelete"))
	assert_eq(String(title.call("_format_slot_summary", {"future_version": true, "version": 9}, false)), "Save schema v9 · requires a newer game version")
	var compatible_text := String(title.call("_format_slot_summary", {
		"future_version": false,
		"season": "Autumn",
		"day_of_season": 12,
		"day": 68,
		"minute_of_day": 600,
		"money": 4321,
		"game_version": "0.1.0",
		"newer_primary_preserved": true,
		"recovery_source": "backup",
	}, true))
	assert_string_contains(compatible_text, "Autumn 12 · Day 68 · 10:00 · 4321g")
	assert_string_contains(compatible_text, "compatible backup · newer save preserved")
	assert_string_contains(compatible_text, "GameBase v0.1.0")

func _cleanup_files() -> void:
	for path in [TEST_SAVE, TEST_TEMP, TEST_BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
