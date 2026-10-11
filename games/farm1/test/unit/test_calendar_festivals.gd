extends GutTest

func test_four_seasonal_festivals_are_registered_on_stable_dates() -> void:
	var expected := {
		&"spring_seed_fair": ["Spring", 9, &"starter_town"],
		&"summer_river_fair": ["Summer", 14, &"riverside_town"],
		&"fall_harbor_derby": ["Autumn", 14, &"harbor_town"],
		&"winter_lantern_night": ["Winter", 21, &"starter_town"],
	}
	assert_eq(CalendarEventData.find_all().size(), 5)
	for event_id: StringName in expected.keys():
		var event := CalendarEventData.find(event_id)
		assert_not_null(event)
		if event == null:
			continue
		var values: Array = expected[event_id]
		assert_eq(Array(event.seasons), [values[0]])
		assert_eq(event.day_of_season, values[1])
		assert_eq(event.location_id, values[2])
		assert_true(event.has_participation_reward())

func test_all_festival_booths_are_exposed_in_playable_town_scenes() -> void:
	var starter := (load("res://game/world/dev_world.tscn") as PackedScene).instantiate()
	var riverside := (load("res://game/world/riverside_town.tscn") as PackedScene).instantiate()
	var harbor := (load("res://game/world/harbor_town.tscn") as PackedScene).instantiate()
	autofree(starter)
	autofree(riverside)
	autofree(harbor)
	assert_not_null(starter.get_node_or_null("SpringSeedFairBooth"))
	assert_not_null(starter.get_node_or_null("WinterLanternBooth"))
	assert_not_null(riverside.get_node_or_null("SummerRiverFairBooth"))
	assert_not_null(harbor.get_node_or_null("FallHarborDerbyBooth"))
	assert_true(ResourceLoader.exists("res://gamebase/modules/lifesim/calendar/calendar_event_booth.tscn"))
