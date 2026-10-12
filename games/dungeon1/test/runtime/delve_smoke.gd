extends "res://gamebase/core/test/runtime_smoke.gd"

## Plays Ember Depths' loop through its scenes: a new game at camp, down into
## the depths and one depth further, each floor cleared with the player's own
## swings, saving refused in the depths and kept at camp, the save loaded back,
## and a defeat that returns the player to camp a quarter poorer. As a main
## loop it compiles before the autoloads exist, so it names no class of the
## game or the foundation and reaches them through the tree.

const CAMP_SCENE := "res://game/world/camp.tscn"
const DEPTHS_SCENE := "res://game/world/depths.tscn"

func _init() -> void:
	smoke_name = "Delve smoke"
	save_directory = "user://delve_smoke"

func _run() -> void:
	var session := root.get_node("GameSession")
	var save_manager := root.get_node("SaveManager")
	var player_state := root.get_node("PlayerState")
	var inventory := root.get_node("InventoryState")
	var depth_run := root.get_node("DepthRun")
	var profile := root.get_node("GameProfile")

	_check(bool(session.start_new_game()), "New game did not start")
	await _arrive(CAMP_SCENE)
	_check(int(player_state.money) == 30 and int(inventory.get_quantity(&"rusty_sword")) == 1, "New game did not start with the camp's kit")

	_use(current_scene.get_node("DepthEntrance/Interactable"))
	await _arrive(DEPTHS_SCENE)
	_check(int(depth_run.get_depth()) == 1 and int(depth_run.get_run()) == 1, "The entrance did not start a run at the first depth")
	_check(not bool(save_manager.save_game()), "Saving in the depths was not refused")
	_check(String(save_manager.get_save_block_reason()) == "Return to camp to save", "The depths gave another reason not to save: %s" % save_manager.get_save_block_reason())
	_use(current_scene.get_node("Stairs/Interactable"))
	await process_frame
	_check(current_scene.scene_file_path == DEPTHS_SCENE and int(depth_run.get_depth()) == 1, "The stairs opened before the floor was cleared")

	await _clear_floor()
	_use(current_scene.get_node("Stairs/Interactable"))
	await _arrive(DEPTHS_SCENE)
	_check(int(depth_run.get_depth()) == 2 and int(depth_run.get_deepest()) == 2, "The stairs did not lead to the second depth")
	_check((current_scene.call("get_enemies") as Array).size() == 3, "The second depth did not spawn three enemies")
	await _clear_floor()
	_use(current_scene.get_node("Rope/Interactable"))
	await _arrive(CAMP_SCENE)
	_check(int(inventory.get_quantity(&"slime_gel")) > 0, "The player came back without what the enemies dropped")
	_check(bool(profile.is_unlocked(&"first_blood")), "Defeating an enemy did not unlock First Blood")
	_check(int(profile.get_int(&"deepest_depth")) == 2, "The profile did not keep the deepest depth")

	var problem: String = save_manager.write_save()
	_check(problem.is_empty(), "Saving at camp failed: %s" % problem)
	var details := Array(save_manager.get_slot_summary(1)["details"])
	_check(details.has("Deepest 2"), "The slot does not show the deepest depth: %s" % [details])
	player_state.money = 1
	_use(current_scene.get_node("DepthEntrance/Interactable"))
	await _arrive(DEPTHS_SCENE)
	var loaded: bool = await save_manager.load_game()
	_check(loaded, "Load failed")
	await _arrive(CAMP_SCENE)
	_check(int(player_state.money) == 30, "Loading did not restore the money (got %d)" % player_state.money)
	_check(int(depth_run.get_run()) == 1 and int(depth_run.get_deepest()) == 2, "Loading did not restore the run")

	_use(current_scene.get_node("DepthEntrance/Interactable"))
	await _arrive(DEPTHS_SCENE)
	_check(int(depth_run.get_run()) == 2 and int(depth_run.get_depth()) == 1, "A new run did not start at the first depth")
	player_state.take_damage(int(player_state.health))
	var money_lost: int = await session.player_collapsed
	await _arrive(CAMP_SCENE)
	_check(money_lost == 8 and int(player_state.money) == 22, "Defeat did not cost a quarter of 30g (lost %d)" % money_lost)
	_check(int(player_state.health) == int(player_state.max_health), "Defeat did not restore the player's health")

# Defeats every enemy of the floor with the player's swings, standing next to
# each in turn.
func _clear_floor() -> void:
	var player := get_first_node_in_group("player") as Node2D
	var melee: Node = player.get_node("MeleeAttack")
	for enemy: Node2D in current_scene.call("get_enemies"):
		for _swing: int in 20:
			if bool(enemy.get("is_defeated")):
				break
			player.global_position = enemy.global_position + Vector2(0, 12)
			await physics_frame
			await physics_frame
			melee.call("attack_selected_weapon")
		_check(bool(enemy.get("is_defeated")), "%s survived twenty swings" % enemy.name)
	await process_frame
	_check(bool(current_scene.call("is_cleared")), "The floor was not cleared")
