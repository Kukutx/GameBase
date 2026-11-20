extends GutTest

## Text a phone shows large enough to read (`ReadableText`): the least font
## size for a view, the core's menus raising their small print to it in a
## narrow view while keeping theirs in a wide one, and the outline that lets
## the HUD's text read over the world.

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

func test_a_line_too_long_for_its_width_shrinks_but_never_below_what_a_phone_reads() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(480, 270)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(view)
	var label := Label.new()
	label.size = Vector2(120, 20)
	view.add_child(label)
	label.text = "Short"
	ReadableText.fit_width(label, 12)
	assert_eq(label.get_theme_font_size(&"font_size"), 12, "a text that fits keeps its size")
	label.text = "Energy 100/100 · Vigor"
	ReadableText.fit_width(label, 12)
	var fitted := label.get_theme_font_size(&"font_size")
	assert_lt(fitted, 12, "a longer one shrinks")
	assert_lte(label.get_theme_font(&"font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x, 120.0, "to fit")
	label.text = "Energy 100/100 · Vigor 100/100 · 123456g · Spring 28 23:50 · Thunderstorm"
	ReadableText.fit_width(label, 12)
	assert_eq(label.get_theme_font_size(&"font_size"), 8, "no smaller than a phone reads in a view 270 high")
	assert_true(label.clip_text, "and the rest is cut rather than run over its neighbour")
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	label.text = "Short"
	ReadableText.fit_width(label, 12)
	assert_eq(label.get_theme_font_size(&"font_size"), 12, "and grows back once it fits again")

func test_an_outline_lets_text_read_over_any_ground() -> void:
	var label := Label.new()
	autofree(label)
	label.add_theme_font_size_override(&"font_size", 12)
	ReadableText.outline(label)
	assert_eq(label.get_theme_constant(&"outline_size"), 3, "a quarter of the font size")
	assert_eq(label.get_theme_color(&"font_outline_color"), ReadableText.OUTLINE_COLOR)
	var small := Label.new()
	autofree(small)
	small.add_theme_font_size_override(&"font_size", 6)
	ReadableText.outline(small)
	assert_eq(small.get_theme_constant(&"outline_size"), 2, "never thinner than 2")
	var own := Label.new()
	autofree(own)
	own.add_theme_constant_override(&"outline_size", 5)
	own.add_theme_color_override(&"font_outline_color", Color.WHITE)
	ReadableText.outline(own)
	assert_eq([own.get_theme_constant(&"outline_size"), own.get_theme_color(&"font_outline_color")], [5, Color.WHITE], "a label's own outline stays")

func test_the_hud_s_lines_and_messages_are_outlined() -> void:
	var line := HudLine.new()
	add_child_autofree(line)
	assert_gt(line.get_theme_constant(&"outline_size"), 0, "a HUD line")
	var plain := HudLine.new()
	plain.outlined = false
	add_child_autofree(plain)
	assert_eq(plain.get_theme_constant(&"outline_size"), 0, "unless it says not")
	var status := StatusLine.new()
	add_child_autofree(status)
	assert_gt(status.get_theme_constant(&"outline_size"), 0, "the messages")
	var saved := SaveIndicator.new()
	add_child_autofree(saved)
	assert_gt(saved.get_theme_constant(&"outline_size"), 0, "the word that the game saved")

func test_a_band_stands_behind_a_message_over_the_world() -> void:
	var label := Label.new()
	label.size = Vector2(200, 20)
	label.add_theme_font_size_override(&"font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_autofree(label)
	assert_false(ReadableText.text_rect(label).has_area(), "no text, no band")
	label.text = "Press E to talk"
	var width := label.get_theme_font(&"font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x
	var rect := ReadableText.text_rect(label)
	assert_almost_eq(rect.size.x, width, 0.5, "as wide as the text")
	assert_almost_eq(rect.position.x, (200.0 - width) / 2.0, 0.5, "where the label centres it")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	assert_almost_eq(ReadableText.text_rect(label).end.x, 200.0, 0.5)
	ReadableText.back(label)
	ReadableText.back(label)
	assert_eq(label.get_child_count(true), 1, "one band behind it, however often it is backed")
	assert_eq(label.get_child_count(), 0, "which is no child a scene or a test counts")
	assert_true((label.get_child(0, true) as Control).show_behind_parent, "drawn under the text")
