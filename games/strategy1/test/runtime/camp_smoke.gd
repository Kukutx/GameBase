extends "res://gamebase/core/test/runtime_smoke.gd"

## Plays Iron Banners: starts a new game, opens the battle at the ford on the
## camp's war table and the battle in the pass from the muster and leaves
## each, walks to the lookout and back through the portals, sleeps in the bed,
## saves, changes state and loads it back.

const START_SCENE := "res://game/world/start.tscn"
const LOOKOUT_SCENE := "res://game/world/lookout.tscn"
const FLAG := &"smoke:new_game"
const COINS := &"smoke:coins"

func _init() -> void:
	smoke_name = "Camp smoke"
	save_directory = "user://camp_smoke"

func _run() -> void:
	var session := root.get_node("GameSession")
	var save_manager := root.get_node("SaveManager")
	var world_state := root.get_node("WorldState")
	var clock := root.get_node("WorldClock")
	var rules := root.get_node("GameRules")

	_check(rules.validate_content(root.get_node("ContentDB")).is_empty(), "Template content has rule problems")
	_check(bool(session.start_new_game()), "New game did not start")
	await _arrive(START_SCENE)
	_check(get_first_node_in_group("player") != null, "Start location has no player")
	var place := current_scene.get_node("Player/HUD/Place") as Label
	_check(place.text.begins_with("Camp · "), "The HUD does not name the camp: '%s'" % place.text)

	var host := root.get_node("MiniGameHost")
	_use(current_scene.get_node("WarTable/Interactable"))
	await process_frame
	_check(bool(host.is_running()) and host.get_active_id() == &"ford_battle", "The war table did not open the battle at the ford")
	var battles := root.find_children("*", "GridBattleGame", true, false)
	# Untyped: a smoke script compiles before the autoloads that the module's
	# classes name exist.
	_check(battles.size() == 1 and int(battles[0].get("battle").get("units").size()) == 8, "The battle at the ford does not show its eight units")
	host.cancel()
	await process_frame
	_check(not bool(host.is_running()), "The battle did not close")

	_use(current_scene.get_node("Muster/Interactable"))
	await process_frame
	_check(bool(host.is_running()) and host.get_active_id() == &"pass_battle", "The muster did not open the battle in the pass")
	var fields := root.find_children("*", "RtsBattleGame", true, false)
	_check(fields.size() == 1 and int(fields[0].get("battle").get("units").size()) == 19, "The battle in the pass does not show its nineteen units")
	host.cancel()
	await process_frame
	_check(not bool(host.is_running()), "The battle in the pass did not close")

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

	world_state.set_value(COINS, 42)
	world_state.set_value(FLAG, true)
	var problem: String = save_manager.write_save()
	_check(problem.is_empty(), "Save failed: %s" % problem)
	world_state.set_value(COINS, 7)
	world_state.set_value(FLAG, false)
	var loaded: bool = await save_manager.load_game()
	_check(loaded, "Load failed")
	_check(int(world_state.get_int(COINS)) == 42, "The world was not restored (got %d)" % world_state.get_int(COINS))
	_check(bool(rules.check("WORLD_FLAG %s, FLAG_AT_LEAST %s 42" % [FLAG, COINS])), "World rules failed after load")

func _player_at(spawn: Node2D) -> bool:
	return (get_first_node_in_group("player") as Node2D).global_position.distance_to(spawn.global_position) < 1.0
