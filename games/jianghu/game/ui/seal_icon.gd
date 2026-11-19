class_name JianghuSealIcon
extends Control

## A square red seal with one character, the icon of a martial art or a realm.

var character := "":
	set(value):
		character = value
		queue_redraw()
var color := JianghuStyle.SEAL:
	set(value):
		color = value
		queue_redraw()

func _init(text := "", seal_color := JianghuStyle.SEAL, side := 34.0) -> void:
	character = text
	color = seal_color
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_style_box(JianghuStyle.box(color, color.darkened(0.25), 2, 4, 0), rect)
	draw_rect(rect.grow(-3), Color(1, 0.95, 0.9, 0.7), false, 1.0)
	var font := get_theme_default_font()
	var font_size := int(rect.size.y * 0.62)
	var text_size := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := rect.get_center() + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	draw_string(font, at, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.96, 0.92))
