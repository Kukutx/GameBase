class_name JianghuStyle
extends RefCounted

## The look of Pocket Jianghu's panels: rice paper, ink and seal red. The theme
## is built in code from flat boxes, so nothing in it waits on an import.

const PAPER := Color(0.97, 0.94, 0.87, 0.97)
const PAPER_DARK := Color(0.9, 0.85, 0.75)
const INK := Color(0.16, 0.13, 0.12)
const INK_SOFT := Color(0.38, 0.33, 0.3)
const SEAL := Color(0.7, 0.18, 0.15)
const SEAL_LIGHT := Color(0.82, 0.3, 0.25)
const JADE := Color(0.27, 0.55, 0.5)
const GOLD := Color(0.85, 0.65, 0.25)

static func box(color: Color, border := Color(0, 0, 0, 0), width := 0, radius := 6, padding := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	return style

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 13
	theme.set_stylebox("panel", "PanelContainer", box(PAPER, INK, 2, 10, 10))
	theme.set_stylebox("panel", "Panel", box(PAPER, INK, 2, 10, 10))
	theme.set_color("font_color", "Label", INK)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color := SEAL
		match state:
			"hover":
				color = SEAL_LIGHT
			"pressed":
				color = SEAL.darkened(0.2)
			"disabled":
				color = Color(0.62, 0.58, 0.54)
		var style := box(color, Color(0, 0, 0, 0), 0, 5, 5)
		if state == "focus":
			style = box(Color(0, 0, 0, 0), GOLD, 2, 5, 5)
		theme.set_stylebox(state, "Button", style)
	for name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(name, "Button", Color(1, 0.97, 0.92))
	theme.set_color("font_disabled_color", "Button", Color(0.95, 0.92, 0.88))
	theme.set_stylebox("background", "ProgressBar", box(PAPER_DARK, INK, 1, 4, 0))
	theme.set_stylebox("fill", "ProgressBar", box(JADE, Color(0, 0, 0, 0), 0, 4, 0))
	theme.set_color("font_color", "ProgressBar", INK)
	theme.set_color("font_color", "CheckButton", INK)
	theme.set_color("font_hover_color", "CheckButton", INK)
	theme.set_color("font_pressed_color", "CheckButton", INK)
	theme.set_color("font_hover_pressed_color", "CheckButton", INK)
	theme.set_color("font_focus_color", "CheckButton", INK)
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", empty)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return theme

## A tab button: paper when off, seal red when on.
static func style_tab(button: Button) -> void:
	button.toggle_mode = true
	button.add_theme_stylebox_override("normal", box(PAPER_DARK, INK_SOFT, 1, 5, 4))
	button.add_theme_stylebox_override("hover", box(PAPER_DARK.lightened(0.2), INK_SOFT, 1, 5, 4))
	button.add_theme_stylebox_override("pressed", box(SEAL, SEAL, 1, 5, 4))
	button.add_theme_stylebox_override("hover_pressed", box(SEAL_LIGHT, SEAL, 1, 5, 4))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)

static func label(text: String, size := 13, color := INK) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result
