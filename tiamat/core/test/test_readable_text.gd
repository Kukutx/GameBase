extends GutTest

## Text a phone shows large enough to read (`ReadableText`): the least font
## size for a view, and the core's menus raising their small print to it in
## a narrow view while keeping theirs in a wide one.

func test_the_least_size_follows_the_view_s_short_side() -> void:
	assert_eq(ReadableText.min_font_size(Vector2(480, 270)), 8, "a view 270 high")
	assert_eq(ReadableText.min_font_size(Vector2(640, 360)), 11, "360 high")
	assert_eq(ReadableText.min_font_size(Vector2(360, 540)), 11, "a phone held upright, 360 wide")
	assert_eq(ReadableText.min_font_size(Vector2(10, 10)), 1)

func test_raising_lifts_only_what_is_too_small() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(360, 540)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(view)
	var root := VBoxContainer.new()
	view.add_child(root)
	var small := Label.new()
	small.add_theme_font_size_override(&"font_size", 9)
	var large := Label.new()
	large.add_theme_font_size_override(&"font_size", 16)
	var rich := RichTextLabel.new()
	rich.add_theme_font_size_override(&"normal_font_size", 10)
	var picture := ColorRect.new()
	for control: Control in [small, large, rich, picture]:
		root.add_child(control)
	ReadableText.raise(root)
	assert_eq(ReadableText.font_size_of(small), 11, "small print rises")
	assert_eq(ReadableText.font_size_of(large), 16, "large print keeps its size")
	assert_eq(rich.get_theme_font_size(&"bold_font_size"), maxi(11, rich.get_theme_default_font_size()), "each of a rich text's fonts")
	assert_eq(ReadableText.font_size_of(rich), 11)
	assert_eq(ReadableText.font_size_of(picture), 0, "what draws no text")

func test_the_core_menus_read_in_a_narrow_view_and_keep_their_look_in_a_wide_one() -> void:
	for size: Vector2 in [Vector2(480, 270), Vector2(360, 540)]:
		var view := SubViewport.new()
		view.size = Vector2i(size)
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child_autofree(view)
		var menu := (load("res://tiamat/core/ui/pause_menu.tscn") as PackedScene).instantiate()
		view.add_child(menu)
		var status := menu.find_child("Status", true, false) as Label
		assert_not_null(status)
		assert_eq(ReadableText.font_size_of(status), maxi(9, ReadableText.min_font_size(size)), "its status line in %s" % size)
