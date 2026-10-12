extends "res://gamebase/core/test/runtime_smoke.gd"

## Boots a game created by tools/new_game.js, which has the GameBase core and
## no module: starts a new game, saves, changes state and loads it back.
## tools/validate.js runs every script under test/runtime/, so a new game keeps
## this check until it replaces it with its own.

const START_SCENE := "res://game/world/start.tscn"
const FLAG := &"smoke:new_game"

func _init() -> void:
	smoke_name = "New game smoke"
	save_directory = "user://new_game_smoke"

func _run() -> void:
	var session := root.get_node("GameSession")
	var save_manager := root.get_node("SaveManager")
	var player_state := root.get_node("PlayerState")
	var world_state := root.get_node("WorldState")
	var rules := root.get_node("GameRules")

	_check(rules.validate_content(root.get_node("ContentDB")).is_empty(), "Template content has rule problems")
	_check(bool(session.start_new_game()), "New game did not start")
	await _arrive(START_SCENE)
	_check(get_first_node_in_group("player") != null, "Start location has no player")

	player_state.money = 42
	world_state.set_value(FLAG, true)
	var problem: String = save_manager.write_save()
	_check(problem.is_empty(), "Save failed: %s" % problem)
	player_state.money = 7
	world_state.set_value(FLAG, false)
	var loaded: bool = await save_manager.load_game()
	_check(loaded, "Load failed")
	_check(player_state.money == 42, "Money was not restored (got %d)" % player_state.money)
	_check(bool(rules.check("WORLD_FLAG %s, MONEY_AT_LEAST 42" % FLAG)), "World flag or money rule failed after load")
