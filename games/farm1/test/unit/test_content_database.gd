extends GutTest

func test_manifest_indexes_all_core_content() -> void:
	var errors := ContentDB.rebuild()
	assert_eq(errors.size(), 0)
	assert_not_null(ItemData.find(&"berry"))
	assert_not_null(CropData.find(&"turnip"))
	assert_not_null(NpcProfileData.find(&"mira"))
	assert_not_null(NpcProfileData.find(&"rowan"))
	assert_not_null(NpcProfileData.find(&"neri"))
	assert_not_null(FarmAnimalData.find(&"chicken"))
	assert_not_null(FarmAnimalData.find(&"cow"))
	assert_not_null(FishData.find(&"river_trout"))
	assert_not_null(FishData.find(&"sardine"))
	assert_not_null(MiningNodeData.find(&"stone_rock"))
	assert_not_null(EnemyData.find(&"green_slime"))
	assert_not_null(QuestData.find(&"first_harvest"))
	assert_not_null(ShopData.find(&"general_store"))
	assert_not_null(RecipeData.find(&"field_snack"))
	assert_not_null(WorldLocationData.find(&"starter_town"))
	assert_not_null(WorldLocationData.find(&"riverside_town"))
	assert_not_null(WorldLocationData.find(&"harbor_town"))
	assert_not_null(AudioCueData.find(&"sfx_pickup"))
	assert_not_null(AudioCueData.find(&"music_old_mine"))

func test_locations_have_packed_scenes_and_unique_default_spawn_points() -> void:
	var locations := WorldLocationData.find_all()
	assert_eq(locations.size(), 5)
	for location: WorldLocationData in locations:
		assert_not_null(location)
		if location == null:
			continue
		var packed := load(location.scene_path) as PackedScene
		assert_not_null(packed, "%s does not resolve to a PackedScene" % location.id)
		if packed == null:
			continue
		var root := packed.instantiate()
		assert_eq(int(ContentDB.call("_count_group_nodes", root, &"player")), 1, "%s must contain exactly one player" % location.id)
		var counts: Dictionary = {}
		ContentDB.call("_collect_spawn_counts", root, counts)
		assert_true(counts.has(String(location.default_spawn_id)), "%s is missing default spawn %s" % [location.id, location.default_spawn_id])
		for raw_spawn_id: Variant in counts.keys():
			var spawn_id := String(raw_spawn_id)
			assert_false(spawn_id.is_empty(), "%s has an empty spawn id" % location.id)
			assert_eq(int(counts[raw_spawn_id]), 1, "%s has duplicate spawn id %s" % [location.id, spawn_id])
		var portals: Array[ScenePortal] = []
		ContentDB.call("_collect_portals", root, portals)
		for portal: ScenePortal in portals:
			assert_ne(portal.target_location_id, &"", "%s has a portal without stable Location ID" % location.id)
		root.free()

func test_location_persistent_state_keys_are_globally_unique() -> void:
	var seen: Dictionary = {}
	for location: WorldLocationData in WorldLocationData.find_all():
		var root := (load(location.scene_path) as PackedScene).instantiate()
		for node: Node in [root] + root.find_children("*", "", true, false):
			if not node.has_method(&"get_persistent_keys"):
				continue
			for key: String in node.call(&"get_persistent_keys"):
				assert_false(seen.has(key), "Persistent state key %s is duplicated" % key)
				seen[key] = "%s/%s" % [location.id, node.name]
		root.free()
	assert_gt(seen.size(), 0)

func test_the_game_handles_its_melee_tool_action() -> void:
	var weapon := ItemData.new()
	weapon.id = &"probe_weapon"
	weapon.kind = ItemData.Kind.TOOL
	weapon.tool_action = MeleeController.TOOL_ACTION
	weapon.max_stack = 1
	assert_eq(ContentDB.find_entry_problems(weapon), PackedStringArray(), "the game registers its attack action")

func test_quest_entry_points_cover_the_entire_registered_graph() -> void:
	var quests := QuestData.find_all()
	assert_eq(quests.size(), 18)
	var entry_ids: Array[String] = []
	var auto_ids: Array[String] = []
	for quest: QuestData in quests:
		if quest.entry_point:
			entry_ids.append(String(quest.id))
		if quest.auto_start:
			auto_ids.append(String(quest.id))
	entry_ids.sort()
	auto_ids.sort()
	assert_eq(entry_ids, ["gather_berries", "meet_mira"])
	assert_eq(auto_ids, ["gather_berries", "meet_mira"])
