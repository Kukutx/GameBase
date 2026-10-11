extends GutTest

func test_content_database_resolves_location_from_scene() -> void:
	var town := WorldLocationData.find_for_scene("res://game/world/dev_world.tscn")
	var home := WorldLocationData.find_for_scene("res://game/world/home_interior.tscn")

	assert_not_null(town)
	assert_eq(town.id, &"starter_town")
	assert_not_null(home)
	assert_eq(home.id, &"player_home")
