class_name MFarmUiArt
extends RefCounted

## The look of MFarm's interface, from the old project's art: its panels,
## slots and font, laid out in the old canvas's 640 by 360 pixels.

const FONT: Font = preload("res://game/unity/fonts/unifont-14.0.01.ttf")
const UI := "res://game/unity/art/UI/%s.tres"
const TEXT_COLOR := Color(0.27, 0.16, 0.1)
const LIGHT_TEXT_COLOR := Color(1, 0.96, 0.86)
## The old game's button tints (Unity's own): under the mouse, pressed and
## disabled; and the outline of the button the keys point at.
const HOVER_TINT := Color(0.96, 0.96, 0.96)
const PRESSED_TINT := Color(0.78, 0.78, 0.78)
const DISABLED_TINT := Color(0.78, 0.78, 0.78, 0.5)
const FOCUS_COLOR := Color(0.667, 0.392, 0.176)

static func texture(texture_name: String) -> Texture2D:
	return load(UI % texture_name) as Texture2D

## A panel of a sliced texture: its border (`metadata/border`) keeps its size.
static func panel(texture_name: String, size: Vector2) -> NinePatchRect:
	var rect := NinePatchRect.new()
	var art := texture(texture_name)
	rect.texture = art
	var border: Vector4i = art.get_meta(&"border", Vector4i.ZERO)
	rect.patch_margin_left = border.x
	rect.patch_margin_top = border.y
	rect.patch_margin_right = border.z
	rect.patch_margin_bottom = border.w
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect

static func image(art: Texture2D, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = art
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func label(text: String, font_size := 8, color := TEXT_COLOR) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override(&"font", FONT)
	result.add_theme_font_size_override(&"font_size", font_size)
	result.add_theme_color_override(&"font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

## Keeps `control` (of `size`) in the middle of its parent, `below` pixels
## lower, whatever the window's width: the title's and the pause menu's paper.
static func centre(control: Control, size: Vector2, below := 0.0) -> void:
	pin(control, size, Vector2(0.5, 0.5), -size / 2 + Vector2(0, below))

## Puts `child` under `parent` with its top left at `at`.
static func place(parent: Control, child: Control, at: Vector2) -> Control:
	child.position = at
	parent.add_child(child)
	return child

## Pins `control`, `size` big, to a point of its parent named as a share of
## the parent's width and height (`point`: (0.5, 0.5) the middle, (1, 0) the
## top right corner, (0.5, 1) the middle of the bottom), its top left corner
## `from_point` away from it (on whole pixels). It keeps to that point
## however wide the screen is: a phone held sideways shows more of the world
## beside the old game's 640 x 360, and the panels stay at its corners and in
## its middle.
static func pin(control: Control, size: Vector2, point: Vector2, from_point: Vector2) -> void:
	var corner := from_point.floor()
	control.anchor_left = point.x
	control.anchor_right = point.x
	control.anchor_top = point.y
	control.anchor_bottom = point.y
	control.offset_left = corner.x
	control.offset_top = corner.y
	control.offset_right = corner.x + size.x
	control.offset_bottom = corner.y + size.y

## A button drawn with one of the old textures, tinted as the old game's
## buttons were (a little darker under the mouse, darker while pressed, faded
## while disabled), with a thin outline while the keys or a gamepad point at
## it. Its text, if any, is in the old font, in the middle of its old size.
static func button(texture_name: String, size: Vector2, text := "", font_size := 8, color := TEXT_COLOR) -> Button:
	var result := Button.new()
	var art := texture(texture_name)
	var border: Vector4i = art.get_meta(&"border", Vector4i.ZERO)
	for state: Array in [[&"normal", Color.WHITE], [&"hover", HOVER_TINT], [&"pressed", PRESSED_TINT], [&"hover_pressed", PRESSED_TINT], [&"disabled", DISABLED_TINT]]:
		var style := StyleBoxTexture.new()
		style.texture = art
		style.texture_margin_left = border.x
		style.texture_margin_top = border.y
		style.texture_margin_right = border.z
		style.texture_margin_bottom = border.w
		# The border slices the art; the words sit in the middle of the
		# button's old size, unpadded, as the old ones did.
		style.set_content_margin_all(0)
		style.modulate_color = state[1]
		result.add_theme_stylebox_override(state[0], style)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(1)
	focus.border_color = FOCUS_COLOR
	focus.set_expand_margin_all(1)
	focus.anti_aliasing = false
	result.add_theme_stylebox_override(&"focus", focus)
	result.add_theme_font_override(&"font", FONT)
	result.add_theme_font_size_override(&"font_size", font_size)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		result.add_theme_color_override(color_name, color)
	result.add_theme_color_override(&"font_disabled_color", Color(color, 0.5))
	result.text = text
	result.custom_minimum_size = size
	result.size = size
	# Out of the tree the words are measured in the default font size, which
	# grows the button; in the tree they take the old size again.
	result.ready.connect(func() -> void: result.size = size, CONNECT_ONE_SHOT)
	return result
