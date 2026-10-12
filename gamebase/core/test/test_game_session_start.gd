extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TEST_DIRECTORY := "user://test_new_game_preflight"
const LOCATION := &"fixture_meadow"

var _save_directory := ""
var _scene_path := TEST_DIRECTORY.path_join("fixture_meadow.tscn")
var _player_snapshot: Dictionary
var _world_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_save_directory = SaveManager.save_directory
	_player_snapshot = PlayerState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	SaveManager.save_directory = TEST_DIRECTORY
	SaveManager.select_slot(SaveManager.active_slot)
	_cleanup()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	WorldTravel.set("_traveling", false)
	_cleanup()
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == _scene_path:
		get_tree().unload_current_scene()
	if FileAccess.file_exists(_scene_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_scene_path))
	SaveManager.save_directory = _save_directory
	SaveManager.select_slot(SaveManager.active_slot)
	PlayerState.load_save_data(_player_snapshot)
	WorldState.load_save_data(_world_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

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
	WorldTravel.set("_traveling", true)

	assert_false(GameSession.start_new_game())
	assert_true(FileAccess.file_exists(SaveManager.save_path))
	assert_eq(FileAccess.get_file_as_string(SaveManager.save_path), "existing-save-must-survive")
	assert_eq(PlayerState.money, 4321)
	assert_eq(String(WorldState.get_value(&"test:new_game_guard", "")), "keep")

func test_a_new_game_is_starting_until_the_player_stands_in_its_start_location() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
	assert_eq(ResourceSaver.save(_location_scene(), _scene_path), OK)
	var location := WorldLocationData.new()
	location.id = LOCATION
	location.display_name = "Meadow"
	location.scene_path = _scene_path
	location.default_spawn_id = &"fixture_gate"
	# The game's own entries stay indexed: the new-game steps of its modules
	# reset their services to its content.
	var registry := ContentFixture.use(self, _game_entries() + [location])
	# Checking the locations reads the spawn points travel needs.
	registry.find_problems()
	var definition := GameDefinition.current().duplicate() as GameDefinition
	definition.start_location_id = LOCATION
	var seen := {}
	var on_scene_changed := func() -> void: seen["scene_changed"] = GameSession.is_starting_new_game()
	var on_started := func() -> void: seen["started"] = GameSession.is_starting_new_game()
	get_tree().scene_changed.connect(on_scene_changed)
	GameSession.new_game_started.connect(on_started)

	# The slot holds a save this build cannot read; the title screen asked
	# before the new game replaces it.
	var unreadable := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	unreadable.store_string("a save of another version")
	unreadable.close()

	var started: bool = ContentFixture.with_definition(definition, GameSession.start_new_game)
	assert_true(started)
	if not started:
		get_tree().scene_changed.disconnect(on_scene_changed)
		GameSession.new_game_started.disconnect(on_started)
		return
	assert_true(GameSession.is_starting_new_game(), "while the start location opens")
	assert_false(FileAccess.file_exists(SaveManager.save_path), "the unreadable save is replaced")
	assert_eq(SaveManager.get_save_block_reason(), "Cannot save while a new game starts")
	await WorldTravel.travel_ended
	# The wait ends inside the arrival's signal; let it return first.
	await get_tree().process_frame
	get_tree().scene_changed.disconnect(on_scene_changed)
	GameSession.new_game_started.disconnect(on_started)
	assert_eq(seen, {"scene_changed": true, "started": false}, "the location's scene loads during the setup; the game starts after it")
	assert_false(GameSession.is_starting_new_game())

func test_ending_activities_calls_each_registered_end_once() -> void:
	var ended := {"count": 0}
	var end := func() -> void: ended["count"] = int(ended["count"]) + 1
	GameSession.register_activity_end(end)
	GameSession.register_activity_end(end)
	GameSession.end_activities()
	assert_eq(int(ended["count"]), 1)
	GameSession.get("_activity_ends").erase(end)

func test_nothing_leaves_for_the_title_while_a_travel_changes_the_scene() -> void:
	var scene := get_tree().current_scene
	WorldTravel.set("_traveling", true)
	assert_false(GameSession.return_to_title(), "the travel's scene would replace the title")
	var menu := (load("res://gamebase/core/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child_autofree(menu)
	menu.open()
	assert_false(menu.visible, "the pause menu waits for the arrival")
	assert_eq(get_tree().current_scene, scene)

func _cleanup() -> void:
	for slot in range(1, GameSaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)

## A location scene with the player and one spawn point.
static func _location_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "FixtureMeadow"
	var player := Node2D.new()
	player.name = "Player"
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
