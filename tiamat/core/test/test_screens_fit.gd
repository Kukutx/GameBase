extends GutTest

## Every screen of the game, its HUD and its menus, the core's and its
## modules' among them, keeps to the edges of a phone held sideways
## (`screen_fit.gd`): in a game whose view widens on a wide screen, a corner's
## text stays in its corner, a line across the screen reaches both sides and
## a menu stays in the middle. A game that lays its screens out in a view of
## another size on some devices, a phone's smaller one so its text reads larger
## (`viewport_width.mobile`), is held to each of them. Every text on the
## screens reads on a phone (`ReadableText`), in the view the game shows one.

const ScreenFit := preload("res://tiamat/core/test/screen_fit.gd")

func test_every_screen_keeps_to_the_edges_of_a_wide_phone() -> void:
	if not ScreenFit.widens():
		pass_test("the view keeps its shape on a wide screen")
		return
	var screens := ScreenFit.find_screens(["res://game", "res://tiamat"])
	assert_gt(screens.size(), 0, "the game has screens")
	var drift := PackedStringArray()
	for size: Vector2 in ScreenFit.view_sizes():
		for path: String in screens:
			for line: String in await ScreenFit.find_drift(self, load(path) as PackedScene, size):
				drift.append("%s at %s %s" % [path, size, line])
	assert_eq(drift, PackedStringArray())

func test_every_screen_s_text_reads_on_a_phone() -> void:
	var screens := ScreenFit.find_screens(["res://game", "res://tiamat"])
	var small := PackedStringArray()
	for path: String in screens:
		for line: String in await ScreenFit.find_small_text(self, load(path) as PackedScene, ScreenFit.phone_size()):
			small.append("%s %s" % [path, line])
	assert_eq(small, PackedStringArray(), "in the view a phone shows, %s" % ScreenFit.phone_size())

func test_small_print_is_found() -> void:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var small := Label.new()
	small.name = "Small"
	small.text = "1.0.0"
	small.add_theme_font_size_override(&"font_size", 6)
	screen.add_child(small)
	small.owner = screen
	var empty := Label.new()
	empty.name = "Empty"
	empty.add_theme_font_size_override(&"font_size", 6)
	screen.add_child(empty)
	empty.owner = screen
	var scene := PackedScene.new()
	scene.pack(screen)
	screen.free()
	assert_eq(await ScreenFit.find_small_text(self, scene, Vector2(480, 270)), PackedStringArray(["Small: 6 px, 8 at least"]))
	assert_eq(await ScreenFit.find_small_text(self, scene, Vector2(240, 135)), PackedStringArray(), "a view half as high needs half the size")

func test_the_views_are_the_game_s_own_then_each_a_device_names() -> void:
	var base := ScreenFit.base_size()
	var sizes := ScreenFit.view_sizes()
	assert_eq(sizes[0], base, "the game's own first")
	var named := "display/window/size/viewport_width.test_device"
	ProjectSettings.set_setting(named, base.x + 100.0)
	var more := ScreenFit.view_sizes()
	ProjectSettings.set_setting(named, null)
	assert_eq(more.size(), sizes.size() + 1, str(more))
	assert_has(more, Vector2(base.x + 100.0, base.y), "a device's, its other side the game's own")
	assert_eq(ScreenFit.view_sizes(), sizes, "and none once it names none")

func test_a_control_held_by_its_offsets_alone_drifts() -> void:
	var hud := CanvasLayer.new()
	var corner := Label.new()
	corner.name = "Corner"
	corner.text = "9:00"
	corner.position = Vector2(400, 4)
	corner.size = Vector2(72, 16)
	hud.add_child(corner)
	corner.owner = hud
	var anchored := Label.new()
	anchored.name = "Anchored"
	anchored.text = "9:00"
	anchored.anchor_left = 1.0
	anchored.anchor_right = 1.0
	anchored.offset_left = -80.0
	anchored.offset_right = -8.0
	anchored.offset_top = 24.0
	anchored.offset_bottom = 40.0
	hud.add_child(anchored)
	anchored.owner = hud
	var scene := PackedScene.new()
	scene.pack(hud)
	hud.free()
	var drift := await ScreenFit.find_drift(self, scene, Vector2(480, 270))
	assert_eq(drift.size(), 1, str(drift))
	assert_string_starts_with(drift[0] if not drift.is_empty() else "", "Corner:")
