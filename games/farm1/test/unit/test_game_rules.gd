extends GutTest

## Farm1's content names only registered condition and action keys, with
## valid arguments. The keys themselves are tested with the layer that
## registers them (gamebase/core/test/test_game_rules.gd and the modules'
## test_*_rules.gd).

func test_all_shipped_content_uses_registered_keys() -> void:
	assert_eq(GameRules.validate_content(ContentDB), PackedStringArray())
