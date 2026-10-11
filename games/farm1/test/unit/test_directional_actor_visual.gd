extends GutTest

func test_direction_name_prefers_dominant_axis() -> void:
	assert_eq(DirectionalActorVisual.direction_name(Vector2(1, 0.2)), &"right")
	assert_eq(DirectionalActorVisual.direction_name(Vector2(-1, 0.2)), &"left")
	assert_eq(DirectionalActorVisual.direction_name(Vector2(0.2, -1)), &"up")
	assert_eq(DirectionalActorVisual.direction_name(Vector2(0.2, 1)), &"down")

func test_zero_direction_defaults_down() -> void:
	assert_eq(DirectionalActorVisual.direction_name(Vector2.ZERO), &"down")

func test_local_craftpix_strips_build_all_directional_animations_when_available() -> void:
	var strip_root := "res://game/art/licensed/craftpix_roguelike/character1"
	if not ResourceLoader.exists(strip_root.path_join("D_Idle.png")):
		pass_test("Licensed character art is intentionally optional")
		return

	var actor := CharacterBody2D.new()
	var body := Polygon2D.new()
	body.name = "Body"
	actor.add_child(body)
	var facing := Polygon2D.new()
	facing.name = "Facing"
	actor.add_child(facing)
	var visual := DirectionalActorVisual.new()
	visual.name = "ActorVisual"
	visual.strip_root = strip_root
	actor.add_child(visual)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	visual.add_child(sprite)
	add_child_autofree(actor)

	assert_not_null(sprite.sprite_frames)
	for animation: StringName in [&"idle_down", &"walk_down", &"idle_up", &"walk_up", &"idle_left", &"walk_left", &"idle_right", &"walk_right"]:
		assert_true(sprite.sprite_frames.has_animation(animation), "Missing animation %s" % animation)
	assert_eq(sprite.sprite_frames.get_frame_count(&"idle_down"), 4)
	assert_eq(sprite.sprite_frames.get_frame_count(&"walk_down"), 6)
	assert_eq(sprite.sprite_frames.get_frame_count(&"attack_down"), 4)
	assert_eq(sprite.sprite_frames.get_frame_count(&"hurt_down"), 2)
	assert_eq(sprite.sprite_frames.get_frame_count(&"death_down"), 8)
	assert_true(sprite.visible)
	assert_false(body.visible)
	assert_false(facing.visible)

	assert_true(visual.play_action(&"attack"))
	assert_true(visual.is_action_playing())
	assert_eq(sprite.animation, &"attack_down")
	visual._on_sprite_animation_finished()
	assert_false(visual.is_action_playing())
	assert_eq(sprite.animation, &"idle_down")
