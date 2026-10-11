extends GutTest

## Farm1's NPC routes and the towns they appear in. How a schedule picks its
## entry is tested with the NPC social module.

func test_core_npcs_have_real_cross_town_routes_for_every_seasonal_festival() -> void:
	var world_snapshot := WorldState.to_save_data()
	var expected := {
		&"event:spring_seed_fair:active": &"starter_town",
		&"event:summer_river_fair:active": &"riverside_town",
		&"event:fall_harbor_derby:active": &"harbor_town",
		&"event:winter_lantern_night:active": &"starter_town",
	}
	for npc_id: StringName in [&"mira", &"rowan", &"neri"]:
		var profile := NpcProfileData.find(npc_id)
		assert_not_null(profile)
		if profile == null:
			continue
		var routes: Dictionary = {}
		for entry: NpcScheduleEntry in profile.schedule_entries:
			if entry != null and expected.has(entry.required_world_flag):
				routes[entry.required_world_flag] = entry
		assert_eq(routes.size(), 4, "%s is missing festival routes" % npc_id)
		for raw_flag: Variant in expected.keys():
			var flag := StringName(String(raw_flag))
			assert_true(routes.has(flag), "%s has no route for %s" % [npc_id, flag])
			if not routes.has(flag):
				continue
			var route: NpcScheduleEntry = routes[flag]
			assert_eq(route.location_id, expected[flag])
			assert_gte(route.priority, 30)
			WorldState.clear()
			WorldState.set_value(flag, true)
			var schedule := NpcSchedule.new()
			add_child_autofree(schedule)
			schedule.entries = profile.schedule_entries
			var selected := schedule.get_entry_for_minute(route.minute_of_day + 30, 1)
			assert_eq(selected, route, "%s festival route did not override normal schedule" % npc_id)
	WorldState.load_save_data(world_snapshot)

func test_all_playable_towns_expose_all_core_npc_instances_for_schedule_presence() -> void:
	for scene_path: String in ["res://game/world/dev_world.tscn", "res://game/world/riverside_town.tscn", "res://game/world/harbor_town.tscn"]:
		var packed := load(scene_path) as PackedScene
		assert_not_null(packed)
		if packed == null:
			continue
		var scene := packed.instantiate()
		add_child_autofree(scene)
		await get_tree().process_frame
		for npc_name: String in ["Mira", "Rowan", "Neri"]:
			assert_not_null(scene.get_node_or_null(npc_name), "%s is missing %s" % [scene_path, npc_name])
