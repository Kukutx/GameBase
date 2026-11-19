extends GutTest

## What the game starts from: a definition that names registered locations and
## content the rules accept.

func test_definition_names_registered_locations() -> void:
	var definition := GameDefinition.current()
	assert_not_null(definition, "tiamat/game_definition names a GameDefinition")
	assert_not_null(WorldLocationData.find(definition.start_location_id), "The start location is registered")
	assert_not_null(WorldLocationData.find(definition.home_location_id), "The home location is registered")

func test_content_passes_the_rules_check() -> void:
	var problems := GameRules.validate_content(ContentDB)
	assert_true(problems.is_empty(), "Content rule problems: %s" % [problems])

func test_every_realm_but_the_last_has_a_gate_and_regions_match() -> void:
	var realms := JianghuRealmData.find_all()
	var regions := JianghuRegionData.find_all()
	assert_eq(realms.size(), regions.size(), "one region for each realm")
	for i: int in realms.size():
		assert_eq(realms[i].order, i, "realm orders run from 0")
		assert_eq(regions[i].order, i, "region orders run from 0")
		if i < realms.size() - 1:
			assert_eq(realms[i].gate_region_id, regions[i].id, "realm %d is gated by region %d" % [i, i])
