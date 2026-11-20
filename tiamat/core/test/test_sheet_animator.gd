extends GutTest

## The frames of a sprite sheet played through a sprite's region
## (`SheetAnimator`): a run that loops or stays on its last frame, row after
## row of the sheet.

func test_a_run_loops_through_its_frames_row_by_row() -> void:
	var sprite := _sheet()
	var animator := SheetAnimator.new(sprite, Vector2i(16, 16), 10)
	animator.play(Vector2i(2, 5))
	assert_eq(sprite.region_rect, Rect2(32, 0, 16, 16), "the run's first frame, the third cell")
	animator.advance(0.25)
	assert_eq(animator.get_frame(), 4, "two and a half frames on")
	assert_eq(sprite.region_rect, Rect2(0, 16, 16, 16), "the fifth cell starts the second row")
	animator.advance(0.25)
	assert_eq(animator.get_frame(), 3, "past its last frame it starts again")

func test_a_run_that_does_not_loop_stays_on_its_last_frame() -> void:
	var sprite := _sheet()
	var animator := SheetAnimator.new(sprite, Vector2i(16, 16), 10)
	animator.play(Vector2i(4, 6), false)
	animator.advance(1.0)
	assert_eq(animator.get_frame(), 6)
	assert_eq(sprite.region_rect, Rect2(32, 16, 16, 16))

func test_the_run_playing_goes_on_and_another_starts_at_its_first_frame() -> void:
	var animator := SheetAnimator.new(_sheet(), Vector2i(16, 16), 10)
	animator.play(Vector2i(0, 3))
	animator.advance(0.25)
	animator.play(Vector2i(0, 3))
	assert_eq(animator.get_frame(), 2, "the same run goes on")
	animator.play(Vector2i(0, 3), true, true)
	assert_eq(animator.get_frame(), 0, "unless it restarts")
	animator.advance(0.25)
	animator.play(Vector2i(0, 3), false)
	assert_eq(animator.get_frame(), 0, "the same frames held at the end are another run")
	animator.play(Vector2i(4, 7))
	assert_eq(animator.get_frame(), 4)

func test_a_sprite_without_a_sheet_is_left_alone() -> void:
	var sprite := _sheet()
	sprite.texture = null
	sprite.region_rect = Rect2(1, 2, 3, 4)
	var animator := SheetAnimator.new(sprite, Vector2i(16, 16), 10)
	animator.play(Vector2i(0, 3))
	animator.advance(0.5)
	assert_eq(sprite.region_rect, Rect2(1, 2, 3, 4))
	assert_eq(animator.get_frame(), 1, "the frames still count")

# A sheet of four columns and two rows of 16-pixel cells.
func _sheet() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	sprite.region_enabled = true
	add_child_autofree(sprite)
	return sprite
