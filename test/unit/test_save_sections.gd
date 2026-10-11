extends GutTest

const PLAYER_HOME := &"player_home"

func test_registered_sections_restore_in_the_documented_order() -> void:
	# Shipping before the clock (no double payout), the clock before the world
	# (saved day markers), quests after the world they read.
	assert_eq(SaveManager.get_section_ids(), PackedStringArray([
		"weather", "shipping", "clock", "buffs", "inventory", "player_state", "hotbar", "world",
		"relationships", "npc_memory", "quests", "skills", "fishing",
	]))

func test_required_sections_follow_the_version_each_section_was_added_in() -> void:
	var expected := {
		1: ["clock", "inventory", "world"],
		2: ["clock", "inventory", "world", "weather", "player_state", "relationships", "quests", "skills"],
		5: ["clock", "inventory", "world", "weather", "player_state", "relationships", "quests", "skills", "npc_memory", "fishing"],
		GameSaveManager.SAVE_VERSION: SaveManager.get_section_ids(),
	}
	for version: int in expected:
		var required: Array[String] = SaveManager.call("_required_dictionary_sections", version)
		var wanted: Array = Array(expected[version])
		required.sort()
		wanted.sort()
		assert_eq(required, wanted, "required sections of version %d" % version)

func test_sections_no_service_owns_survive_the_next_save() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.set("_carried_sections", {"future_module": {"value": 3}})
	var snapshot := manager.build_snapshot()
	assert_eq(int((snapshot.get("future_module", {}) as Dictionary).get("value", 0)), 3)
	for id: String in manager.get_section_ids():
		assert_true(snapshot.get(id) is Dictionary, "section %s is written" % id)
	manager.clear_carried_sections()
	assert_false(manager.build_snapshot().has("future_module"))

func test_game_definition_supplies_the_games_facts() -> void:
	var definition := GameSession.definition
	assert_not_null(definition)
	assert_ne(definition.start_location_id, &"")
	assert_not_null(ContentDB.get_location(definition.start_location_id))
	assert_eq(definition.home_location_id, PLAYER_HOME)
	assert_not_null(ContentDB.get_location(definition.home_location_id))
	for item_id: StringName in definition.start_items:
		assert_not_null(ItemCatalog.get_item(item_id), "start item %s exists" % item_id)
		assert_gt(definition.start_items[item_id], 0)
