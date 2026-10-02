extends GutTest

const TEST_SAVE := "user://new_game_preflight_guard.json"
const TEST_TEMP := "user://new_game_preflight_guard.tmp"
const TEST_BACKUP := "user://new_game_preflight_guard.bak"

var _save_path := ""
var _temp_path := ""
var _backup_path := ""
var _player_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_save_path = SaveManager.save_path
	_temp_path = SaveManager.temp_path
	_backup_path = SaveManager.backup_path
	_player_snapshot = PlayerState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	SaveManager.save_path = TEST_SAVE
	SaveManager.temp_path = TEST_TEMP
	SaveManager.backup_path = TEST_BACKUP
	_cleanup()

func after_each() -> void:
	WorldTravel.set("_traveling", false)
	SaveManager.save_path = _save_path
	SaveManager.temp_path = _temp_path
	SaveManager.backup_path = _backup_path
	PlayerState.load_save_data(_player_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	WorldState.load_save_data(_world_snapshot)
	_cleanup()

func test_new_game_preflight_failure_preserves_existing_save_and_session() -> void:
	var sentinel := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	assert_not_null(sentinel)
	if sentinel == null:
		return
	sentinel.store_string("existing-save-must-survive")
	sentinel.close()
	PlayerState.money = 4321
	WorldState.set_value(&"test:new_game_guard", "keep")
	var inventory_before := InventoryState.to_save_data()
	WorldTravel.set("_traveling", true)

	assert_false(GameSession.start_new_game())
	assert_true(FileAccess.file_exists(TEST_SAVE))
	assert_eq(FileAccess.get_file_as_string(TEST_SAVE), "existing-save-must-survive")
	assert_eq(PlayerState.money, 4321)
	assert_eq(String(WorldState.get_value(&"test:new_game_guard", "")), "keep")
	assert_eq(InventoryState.to_save_data(), inventory_before)

func _cleanup() -> void:
	for path in [TEST_SAVE, TEST_TEMP, TEST_BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
