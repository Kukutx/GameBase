extends GutTest

## What a new game starts from: a definition that names registered locations and
## content the rules accept. Extend these with the game's own tests.

func test_definition_names_registered_locations() -> void:
	var definition := GameDefinition.current()
	assert_not_null(definition, "gamebase/game_definition names a GameDefinition")
	assert_not_null(LocationCatalog.get_location(definition.start_location_id), "The start location is registered")
	assert_not_null(LocationCatalog.get_location(definition.home_location_id), "The home location is registered")

func test_content_passes_the_rules_check() -> void:
	var problems := GameRules.validate_content(ContentDB)
	assert_true(problems.is_empty(), "Content rule problems: %s" % [problems])
