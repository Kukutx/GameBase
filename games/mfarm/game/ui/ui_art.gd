class_name MFarmUiArt
extends RefCounted

## The look of MFarm's interface, from the old project's art: its panels,
## slots and font, laid out in the old canvas's 640 by 360 pixels.

const FONT: Font = preload("res://game/unity/fonts/unifont-14.0.01.ttf")
const UI := "res://game/unity/art/UI/%s.tres"
const TEXT_COLOR := Color(0.27, 0.16, 0.1)
const LIGHT_TEXT_COLOR := Color(1, 0.96, 0.86)

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

## Puts `child` under `parent` with its top left at `at`.
static func place(parent: Control, child: Control, at: Vector2) -> Control:
	child.position = at
	parent.add_child(child)
	return child
