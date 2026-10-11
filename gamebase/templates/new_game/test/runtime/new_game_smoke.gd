extends SceneTree

## Boots a game created by tools/new_game.js, which has the GameBase core and
## no module: starts a new game, saves, changes state and loads it back.
## tools/validate.js runs every script under test/runtime/, so a new game keeps
## this check until it replaces it with its own.

const SAVE_DIRECTORY := "user://new_game_smoke"
const FLAG := &"smoke:new_game"

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("GameSession")
	var save_manager := root.get_node("SaveManager")
	var player_state := root.get_node("PlayerState")
	var world_state := root.get_node("WorldState")
	var rules := root.get_node("GameRules")
	save_manager.save_directory = SAVE_DIRECTORY
	save_manager.select_slot(1)
	_cleanup()

	_check(rules.validate_content(root.get_node("ContentDB")).is_empty(), "Template content has rule problems")
	_check(bool(session.start_new_game()), "New game did not start")
	var start_scene := "res://game/world/start.tscn"
	for frame in 300:
		if current_scene != null and current_scene.scene_file_path == start_scene and not root.get_node("WorldTravel").is_traveling():
			break
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == start_scene, "New game did not open the start location")
	_check(get_first_node_in_group("player") != null, "Start location has no player")

	player_state.money = 42
	world_state.set_value(FLAG, true)
	_check(bool(save_manager.save_game()), "Save failed: %s" % save_manager.get_save_block_reason())
	player_state.money = 7
	world_state.set_value(FLAG, false)
	var loaded: bool = await save_manager.load_game()
	_check(loaded, "Load failed")
	_check(player_state.money == 42, "Money was not restored (got %d)" % player_state.money)
	_check(bool(rules.check("WORLD_FLAG %s, MONEY_AT_LEAST 42" % FLAG)), "World flag or money rule failed after load")

	_cleanup()
	if _failed:
		quit(1)
		return
	print("New game smoke passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("NEW GAME SMOKE FAILED: %s" % message)

func _cleanup() -> void:
	root.get_node("SaveManager").delete_slot(1)
