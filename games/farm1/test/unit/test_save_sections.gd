extends GutTest

const PLAYER_HOME := &"player_home"

func test_registered_sections_restore_in_the_documented_order() -> void:
	# Shipping before the clock (no double payout), the clock before the world
	# (saved day markers), quests after the world they read.
	assert_eq(SaveManager.get_section_ids(), PackedStringArray([
		"weather", "shipping", "clock", "buffs", "inventory", "player_state", "hotbar", "world",
		"relationships", "npc_memory", "quests", "skills", "fishing_state",
	]))

func test_snapshot_writes_every_registered_section_and_nothing_else() -> void:
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	var snapshot := manager.build_snapshot()
	var keys: Array[String] = []
	for key: Variant in snapshot.keys():
		keys.append(String(key))
	keys.sort()
	var expected: Array[String] = []
	expected.append_array(GameSaveManager.HEADER_KEYS)
	expected.append_array(Array(manager.get_section_ids()))
	expected.sort()
	assert_eq(keys, expected)
	for id: String in manager.get_section_ids():
		assert_true(snapshot.get(id) is Dictionary, "section %s is written" % id)

func test_game_definition_supplies_the_games_facts() -> void:
	var definition := GameSession.definition
	assert_not_null(definition)
	assert_ne(definition.start_location_id, &"")
	assert_not_null(WorldLocationData.find(definition.start_location_id))
	assert_eq(definition.home_location_id, PLAYER_HOME)
	assert_not_null(WorldLocationData.find(definition.home_location_id))
	for item_id: StringName in definition.start_items:
		assert_not_null(ItemData.find(item_id), "start item %s exists" % item_id)
		assert_gt(definition.start_items[item_id], 0)
