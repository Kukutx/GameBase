extends GutTest

## What a new game starts from: a definition that names registered locations and
## content the rules accept. Extend these with the game's own tests.

func test_definition_names_registered_locations() -> void:
	var definition := GameDefinition.current()
	assert_not_null(definition, "gamebase/game_definition names a GameDefinition")
	assert_not_null(WorldLocationData.find(definition.start_location_id), "The start location is registered")
	assert_not_null(WorldLocationData.find(definition.home_location_id), "The home location is registered")

func test_content_passes_the_rules_check() -> void:
	var problems := GameRules.validate_content(ContentDB)
	assert_true(problems.is_empty(), "Content rule problems: %s" % [problems])

func test_the_player_walks_and_uses_what_is_near() -> void:
	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as TopDownPlayer
	add_child_autofree(player)
	assert_not_null(player, "the player is a TopDownPlayer")
	var controller := player.get_node("InteractionController") as InteractionController
	assert_not_null(controller.prompt_label, "the HUD shows what is near")
	player.face(Vector2.RIGHT)
	assert_eq(controller.position, Vector2.RIGHT * player.reach, "what the player uses is in front of them")
