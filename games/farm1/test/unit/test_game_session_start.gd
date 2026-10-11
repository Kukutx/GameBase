extends GutTest

const TEST_DIRECTORY := "user://test_new_game_preflight"

var _save_directory := ""
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_save_directory = SaveManager.save_directory
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	SaveManager.save_directory = TEST_DIRECTORY
	SaveManager.select_slot(SaveManager.active_slot)
	_cleanup()

func after_each() -> void:
	WorldTravel.set("_traveling", false)
	_cleanup()
	SaveManager.save_directory = _save_directory
	SaveManager.select_slot(SaveManager.active_slot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_new_game_preflight_failure_preserves_existing_save_and_session() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
	var sentinel := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
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
	assert_true(FileAccess.file_exists(SaveManager.save_path))
	assert_eq(FileAccess.get_file_as_string(SaveManager.save_path), "existing-save-must-survive")
	assert_eq(PlayerState.money, 4321)
	assert_eq(String(WorldState.get_value(&"test:new_game_guard", "")), "keep")
	assert_eq(InventoryState.to_save_data(), inventory_before)

func _cleanup() -> void:
	for slot in range(1, GameSaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
