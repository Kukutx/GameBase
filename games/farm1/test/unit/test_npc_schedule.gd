extends GutTest

## Farm1's NPC routes and the towns they appear in. How a schedule picks its
## entry is tested with the NPC social module.

func test_core_npcs_have_real_cross_town_routes_for_every_seasonal_festival() -> void:
	var expected := {
		&"spring_seed_fair": &"starter_town",
		&"summer_river_fair": &"riverside_town",
		&"fall_harbor_derby": &"harbor_town",
		&"winter_lantern_night": &"starter_town",
	}
	for npc_id: StringName in [&"mira", &"rowan", &"neri"]:
		var profile := NpcProfileData.find(npc_id)
		assert_not_null(profile)
		if profile == null:
			continue
		var routes: Dictionary = {}
		for entry: NpcScheduleEntry in profile.schedule_entries:
			for raw_event_id: Variant in expected.keys():
				if entry != null and entry.condition == "EVENT_ACTIVE %s" % raw_event_id:
					routes[raw_event_id] = entry
		assert_eq(routes.size(), 4, "%s is missing festival routes" % npc_id)
		for raw_event_id: Variant in expected.keys():
			var event_id := StringName(String(raw_event_id))
			assert_true(routes.has(event_id), "%s has no route for %s" % [npc_id, event_id])
			if not routes.has(event_id):
				continue
			var route: NpcScheduleEntry = routes[event_id]
			assert_eq(route.location_id, expected[event_id])
			assert_gte(route.priority, 30)
			var minute := route.minute_of_day + 30
			var day := _first_day_on(CalendarEventData.find(event_id), minute)
			assert_gt(day, 0, "%s is never on when %s's route starts" % [event_id, npc_id])
			var schedule := NpcSchedule.new()
			add_child_autofree(schedule)
			schedule.entries = profile.schedule_entries
			var selected := schedule.get_entry_for_minute(minute, day)
			assert_eq(selected, route, "%s festival route did not override normal schedule" % npc_id)

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

## The first day of the year `event` is on at `minute_of_day`, or 0.
func _first_day_on(event: CalendarEventData, minute_of_day: int) -> int:
	if event == null:
		return 0
	for day: int in range(1, GameClock.DAYS_PER_SEASON * GameClock.SEASON_NAMES.size() + 1):
		if event.is_active(day, minute_of_day):
			return day
	return 0
