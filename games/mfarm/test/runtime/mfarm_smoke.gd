extends "res://tiamat/core/test/runtime_smoke.gd"

## Plays MFarm: starts a new game on the beach, walks to the field, takes the
## hoe out of the tool box, digs, waters and plants a cell, goes on to the
## market, talks to Koyo and buys seeds at her stall, then saves, changes the
## world and loads it back.

const BEACH := "res://game/world/beach.tscn"
const FIELD := "res://game/world/field.tscn"
const MARKET := "res://game/world/market.tscn"
## A cell of the field's plot, and where the player stands to work it.
const PLOT_CELL := Vector2i(16, 2)

func _init() -> void:
	smoke_name = "MFarm smoke"
	save_directory = "user://mfarm_smoke"

func _run() -> void:
	var session := root.get_node("GameSession")
	var save_manager := root.get_node("SaveManager")
	var rules := root.get_node("GameRules")
	var bags := root.get_node("Bags")
	var land := root.get_node("Farmland")

	_check(rules.validate_content(root.get_node("ContentDB")).is_empty(), "MFarm content has rule problems")
	_check(bool(session.start_new_game()), "New game did not start")
	if not await _arrive(BEACH):
		return
	_check(get_first_node_in_group("player") != null, "The beach has no player")
	_check(int(bags.get("money")) == 100, "The player does not start with 100 coins")
	_check(current_scene.get_node_or_null("Townsfolk/mike") != null, "Mike is not on the beach")

	await _walk_into(current_scene.get_node("Map/Teleport To Field"))
	if not await _arrive(FIELD):
		return
	_check(_player_at(current_scene.get_node("SpawnPoints/from_beach")), "The player did not arrive by the beach path")
	_check(current_scene.get_node_or_null("Townsfolk/mayor") != null, "The mayor is not in the field")

	var box := current_scene.get_node("Map/Item Parent/Tool Box")
	box.call("open")
	var box_key: StringName = box.get("box_key")
	var tools: Array = bags.call("get_slots", box_key)
	var hoe_index := -1
	var can_index := -1
	for index: int in tools.size():
		if tools[index].item == &"hoe":
			hoe_index = index
		elif tools[index].item == &"watering_can":
			can_index = index
	_check(hoe_index >= 0 and can_index >= 0, "The tool box holds no hoe or watering can")
	_check(bool(bags.call("move_slot", box_key, hoe_index, &"player", 0)), "The hoe did not move to the bag")
	_check(bool(bags.call("move_slot", box_key, can_index, &"player", 1)), "The watering can did not move to the bag")
	(get_first_node_in_group("mfarm_bag_menu") as Node).call("close")

	var player := get_first_node_in_group("player") as Node2D
	var target := Vector2(PLOT_CELL) * 20.0 + Vector2(10, 10)
	player.global_position = target + Vector2(0, 22)
	bags.call("select", 0)
	_check(bool(player.call("use_item", target)), "The hoe could not dig the plot")
	await _wait_seconds(1.0)
	_check(bool(land.call("is_dug", &"field", PLOT_CELL)), "The plot was not dug")
	bags.call("select", 1)
	_check(bool(player.call("use_item", target)), "The watering can could not water the plot")
	await _wait_seconds(1.0)
	_check(bool(land.call("is_watered", &"field", PLOT_CELL)), "The plot was not watered")

	await _walk_into(current_scene.get_node("To Market"))
	if not await _arrive(MARKET):
		return
	var koyo := current_scene.get_node_or_null("Townsfolk/koyo")
	_check(koyo != null, "Koyo is not at the market")
	if koyo == null:
		return
	_check(bool(koyo.call("can_talk")), "Koyo cannot be talked to")
	koyo.get_node("Interactable").call("interact", get_first_node_in_group("player"))
	var dialogue := get_first_node_in_group("mfarm_dialogue_box")
	_check(bool(dialogue.call("is_talking")), "Talking to Koyo shows no conversation")
	for _line: int in 4:
		if bool(dialogue.call("is_talking")):
			dialogue.call("_next")
	await process_frame
	_check(not bool(dialogue.call("is_talking")), "The conversation with Koyo did not end")
	_check(bool(bags.call("has_bag", &"shop:koyo")), "Koyo's stall did not open after the talk")
	_check(bool(bags.call("buy", &"shop:koyo", 0, 1)), "Buying a seed failed")
	_check(int(bags.call("count", &"player", &"potato_seed")) == 1, "The bought seed is not in the bag")
	var money := int(bags.get("money"))
	_check(money < 100, "Buying cost nothing")
	(get_first_node_in_group("mfarm_bag_menu") as Node).call("close")

	var problem: String = save_manager.write_save()
	_check(problem.is_empty(), "Save failed: %s" % problem)
	bags.call("set_money", 5)
	var loaded: bool = await save_manager.load_game()
	_check(loaded, "Load failed")
	_check(int(bags.get("money")) == money, "The money was not restored (got %d)" % int(bags.get("money")))
	_check(bool(land.call("is_dug", &"field", PLOT_CELL)), "The dug plot was not restored")
	_check(int(bags.call("count", &"player", &"hoe")) == 1, "The hoe did not stay in the bag")

func _player_at(spawn: Node2D) -> bool:
	return (get_first_node_in_group("player") as Node2D).global_position.distance_to(spawn.global_position) < 1.0

func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
