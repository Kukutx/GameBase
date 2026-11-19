extends GutTest

## Every screen of the game, its HUD and its menus, the core's and its
## modules' among them, keeps to the edges of a phone held sideways
## (`screen_fit.gd`): in a game whose view widens on a wide screen, a corner's
## text stays in its corner, a line across the screen reaches both sides and
## a menu stays in the middle.

const ScreenFit := preload("res://tiamat/core/test/screen_fit.gd")

func test_every_screen_keeps_to_the_edges_of_a_wide_phone() -> void:
	if not ScreenFit.widens():
		pass_test("the view keeps its shape on a wide screen")
		return
	var screens := ScreenFit.find_screens(["res://game", "res://tiamat"])
	assert_gt(screens.size(), 0, "the game has screens")
	var drift := PackedStringArray()
	for path: String in screens:
		for line: String in await ScreenFit.find_drift(self, load(path) as PackedScene):
			drift.append("%s %s" % [path, line])
	assert_eq(drift, PackedStringArray())

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
