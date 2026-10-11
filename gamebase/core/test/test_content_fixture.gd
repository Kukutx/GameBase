extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_fixture_content_replaces_the_game_content_until_the_test_ends() -> void:
	var location := WorldLocationData.new()
	location.id = &"fixture_meadow"
	location.display_name = "Meadow"
	var registry := ContentFixture.use(self, [location])
	assert_eq(ContentRegistry.active, registry)
	assert_eq(WorldLocationData.find(&"fixture_meadow"), location)
	assert_eq(WorldLocationData.find_all(), [location])
	assert_eq(registry.get_kinds(), ContentDB.get_kinds(), "the fixture knows every kind the game's modules registered")

	remove_child(registry)
	assert_eq(ContentRegistry.active, ContentDB)
	assert_null(WorldLocationData.find(&"fixture_meadow"))
