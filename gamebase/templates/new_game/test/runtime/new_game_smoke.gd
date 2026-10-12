extends "res://gamebase/core/test/runtime_smoke.gd"

## Plays a game created by tools/new_game.js, which has the GameBase core and
## no module: starts a new game, walks to the lookout and back through the
## portals, sleeps in the bed, saves, changes state and loads it back.
## tools/validate.js runs every script under test/runtime/, so a new game keeps
## this check until it replaces it with its own.

const START_SCENE := "res://game/world/start.tscn"
const LOOKOUT_SCENE := "res://game/world/lookout.tscn"
const FLAG := &"smoke:new_game"

func _init() -> void:
	smoke_name = "New game smoke"
	save_directory = "user://new_game_smoke"

func _run() -> void:
	var session := root.get_node("GameSession")
	var save_manager := root.get_node("SaveManager")
	var player_state := root.get_node("PlayerState")
	var world_state := root.get_node("WorldState")
	var clock := root.get_node("WorldClock")
	var rules := root.get_node("GameRules")

	_check(rules.validate_content(root.get_node("ContentDB")).is_empty(), "Template content has rule problems")
	_check(bool(session.start_new_game()), "New game did not start")
	await _arrive(START_SCENE)
	_check(get_first_node_in_group("player") != null, "Start location has no player")
	var place := current_scene.get_node("Player/HUD/Place") as Label
	_check(place.text.begins_with("Starting Point · "), "The HUD does not name the start: '%s'" % place.text)

	await _walk_into(current_scene.get_node("ToLookout"))
	if not await _arrive(LOOKOUT_SCENE):
		return
	_check(_player_at(current_scene.get_node("FromStartSpawn")), "The player did not arrive by the path from the start")
	await _walk_into(current_scene.get_node("ToStart"))
	if not await _arrive(START_SCENE):
		return
	_check(_player_at(current_scene.get_node("FromLookoutSpawn")), "The player did not come back by the path from the lookout")

	_use(current_scene.get_node("Bed/Interactable"))
	_check(int(clock.day) == 2, "Sleeping did not lead to the next day (day %d)" % clock.day)
	_check(bool(save_manager.has_save()), "Sleeping did not save")

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

func _player_at(spawn: Node2D) -> bool:
	return (get_first_node_in_group("player") as Node2D).global_position.distance_to(spawn.global_position) < 1.0
