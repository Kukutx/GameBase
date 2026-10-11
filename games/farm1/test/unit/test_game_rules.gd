extends GutTest

## Farm1's content names only registered condition and action keys, with
## valid arguments. The keys themselves are tested with the layer that
## registers them (gamebase/core/test/test_game_rules.gd and the modules'
## test_*_rules.gd).

func test_all_shipped_content_uses_registered_keys() -> void:
	assert_eq(GameRules.validate_content(ContentDB), PackedStringArray())

func test_a_farming_level_condition_runs_from_one_to_ten() -> void:
	assert_eq(GameRules.validate_query("SKILL_LEVEL farming 10"), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_query("SKILL_LEVEL farming 11")), "skill 'farming' has no level 11 (1-10)")
