extends GutTest

func test_direction_name_prefers_dominant_axis() -> void:
	assert_eq(DirectionalActorVisual.direction_name(Vector2(1, 0.2)), &"right")
	assert_eq(DirectionalActorVisual.direction_name(Vector2(-1, 0.2)), &"left")
	assert_eq(DirectionalActorVisual.direction_name(Vector2(0.2, -1)), &"up")
	assert_eq(DirectionalActorVisual.direction_name(Vector2(0.2, 1)), &"down")

func test_zero_direction_defaults_down() -> void:
	assert_eq(DirectionalActorVisual.direction_name(Vector2.ZERO), &"down")

func test_an_action_plays_over_the_idle_animation_and_returns_to_it() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	for animation: StringName in [&"idle_down", &"attack_down"]:
		frames.add_animation(animation)
		frames.add_frame(animation, texture)
	frames.set_animation_loop(&"attack_down", false)

	var actor := CharacterBody2D.new()
	var body := Polygon2D.new()
	body.name = "Body"
	actor.add_child(body)
	var facing := Polygon2D.new()
	facing.name = "Facing"
	actor.add_child(facing)
	var visual := DirectionalActorVisual.new()
	visual.name = "ActorVisual"
	visual.sprite_frames = frames
	actor.add_child(visual)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	visual.add_child(sprite)
	add_child_autofree(actor)

	assert_eq(sprite.sprite_frames, frames)
	assert_eq(sprite.animation, &"idle_down")
	assert_true(sprite.visible)
	assert_false(body.visible, "the fallback body hides while the sprite has an animation")
	assert_false(facing.visible)

	assert_false(visual.play_action(&"hurt"), "an action without an animation does not play")
	assert_true(visual.play_action(&"attack"))
	assert_true(visual.is_action_playing())
	assert_eq(sprite.animation, &"attack_down")
	visual._on_sprite_animation_finished()
	assert_false(visual.is_action_playing())
	assert_eq(sprite.animation, &"idle_down")
