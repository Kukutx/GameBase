class_name MFarmPause
extends PauseMenu

## MFarm's pause menu, the old game's: the title's sheet of paper over the
## dimmed world, its sheets' tabs leaning out of its right edge. The gear on
## the time panel opens it, as the old gear did, and so does Esc, which also
## closes it; a tab brings its sheet to the top, and the sheet on top stays
## there the next time.
##
## - 设置 (blue, on top as in the old menu): the music volume (the old slider
##   said 背景音乐 but turned every sound down; it turns the music now), the
##   sound volume (the old 音效 switch was never finished) and the rest of the
##   settings.
## - 休息 (red): back to the game (which the old notes asked for), back to the
##   title and quit. A web page has no quit.
## - 存档 (yellow, new): save and load, which the core's menu offers and the
##   old one did not.
##
## What the menu does is the core's (`PauseMenu`); this is how it looks.

enum Sheet { SAVES, REST, SETTINGS }

const PAPER_SIZE := Vector2(243, 161)
const DIM_COLOR := Color(0, 0, 0, 0.392)
const TEXT_COLOR := Color(0.196, 0.196, 0.196)
const LABEL_COLOR := Color(0.529, 0.235, 0.235)
const STATUS_COLOR := Color(0.95, 0.88, 0.72)
## The old slider: its track, the part filled and its handle.
const TRACK_COLOR := Color(0.933, 0.749, 0.49)
const FILL_COLOR := Color(0.863, 0.529, 0.235)
## Each sheet's tab: its art, its word and where its middle sits on the paper
## (the old tabs stood 25 pixels apart by the right edge).
const TABS := {
	Sheet.SAVES: ["ui_paper_06", "Saves", Vector2(240, 80)],
	Sheet.REST: ["ui_paper_05", "Rest", Vector2(240, 130)],
	Sheet.SETTINGS: ["ui_paper_07", "Setup", Vector2(240, 105)],
}
const TAB_SIZE := Vector2(38, 14)
## The old tabs leaned 20 degrees.
const TAB_TILT := 20.0
const BUTTON_SIZE := Vector2(148, 30)
const SLIDER_SIZE := Vector2(160, 20)

var paper: Control
## Each sheet's page, by Sheet: its content shows while it is on top.
var sheets: Dictionary[Sheet, Control] = {}
var contents: Dictionary[Sheet, Control] = {}
var tabs: Dictionary[Sheet, Button] = {}
var music_slider: HSlider
var sounds_slider: HSlider
var shown := Sheet.SETTINGS

func _ready() -> void:
	_build()
	super()
	show_sheet(shown)
	GameSettings.changed.connect(_show_volumes)
	_show_volumes()

## Brings `sheet` to the top, as the old game's tabs did.
func show_sheet(sheet: Sheet) -> void:
	shown = sheet
	paper.move_child(sheets[sheet], -1)
	for each: Sheet in contents:
		contents[each].visible = each == sheet

func _focus_on_open() -> void:
	_focus_sheet(shown)

func _set_main_buttons_disabled(value: bool) -> void:
	super(value)
	for tab: Button in tabs.values():
		tab.disabled = value
	music_slider.editable = not value
	sounds_slider.editable = not value
	music_slider.focus_mode = Control.FOCUS_NONE if value else Control.FOCUS_ALL
	sounds_slider.focus_mode = music_slider.focus_mode

func _on_tab_pressed(sheet: Sheet) -> void:
	show_sheet(sheet)
	_focus_sheet(sheet)

# The first thing on the sheet: a slider or a button.
func _focus_sheet(sheet: Sheet) -> void:
	match sheet:
		Sheet.SETTINGS:
			music_slider.grab_focus()
		Sheet.REST:
			resume_button.grab_focus()
		Sheet.SAVES:
			save_button.grab_focus()

func _show_volumes() -> void:
	music_slider.set_value_no_signal(GameSettings.music_volume)
	sounds_slider.set_value_no_signal(GameSettings.sounds_volume)

func _build() -> void:
	layer = 100
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	paper = Control.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MFarmUiArt.centre(paper, PAPER_SIZE, 0.0)
	dim.add_child(paper)
	paper.add_child(MFarmUiArt.image(MFarmUiArt.texture("ui_paper_01"), PAPER_SIZE))
	for sheet: Sheet in [Sheet.SAVES, Sheet.REST, Sheet.SETTINGS]:
		_build_sheet(sheet)
	_build_settings(contents[Sheet.SETTINGS])
	_build_rest(contents[Sheet.REST])
	_build_saves(contents[Sheet.SAVES])

	status_label = MFarmUiArt.label("", 8, STATUS_COLOR)
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MFarmUiArt.centre(status_label, Vector2(PAPER_SIZE.x + 120, 24), PAPER_SIZE.y / 2 + 24)
	dim.add_child(status_label)

func _build_sheet(sheet: Sheet) -> void:
	var page := Control.new()
	page.name = String(Sheet.keys()[sheet]).capitalize()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size = PAPER_SIZE
	paper.add_child(page)
	page.add_child(MFarmUiArt.image(MFarmUiArt.texture("ui_paper"), PAPER_SIZE))
	var content := Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = PAPER_SIZE
	page.add_child(content)
	var tab_art: Array = TABS[sheet]
	var tab := MFarmUiArt.button(tab_art[0], TAB_SIZE, tab_art[1], 8, TEXT_COLOR)
	tab.name = "Tab"
	tab.pivot_offset = TAB_SIZE / 2
	tab.rotation_degrees = TAB_TILT
	tab.pressed.connect(_on_tab_pressed.bind(sheet))
	MFarmUiArt.place(page, tab, (tab_art[2] as Vector2) - TAB_SIZE / 2)
	sheets[sheet] = page
	contents[sheet] = content
	tabs[sheet] = tab

# A button of the old menu (148 by 30, its word in the old font) whose middle
# is `middle_y` pixels down the paper.
func _sheet_button(content: Control, node_name: String, text: String, middle_y: float) -> Button:
	var button := MFarmUiArt.button("ui_paper_02", BUTTON_SIZE, text, 14, TEXT_COLOR)
	button.name = node_name
	MFarmUiArt.place(content, button, Vector2(floorf((PAPER_SIZE.x - BUTTON_SIZE.x) / 2), floorf(middle_y - BUTTON_SIZE.y / 2)))
	return button

# The old 背景音乐 slider: its words above it, a track that fills as it rises
# and the old handle.
func _volume(content: Control, node_name: String, text: String, middle_y: float, setter: Callable) -> HSlider:
	var left := floorf((PAPER_SIZE.x - SLIDER_SIZE.x) / 2)
	var words := MFarmUiArt.label(text, 10, LABEL_COLOR)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.size = Vector2(SLIDER_SIZE.x, 20)
	MFarmUiArt.place(content, words, Vector2(left, floorf(middle_y - 25 - 10)))
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size = SLIDER_SIZE
	slider.custom_minimum_size = SLIDER_SIZE
	var track := _bar(TRACK_COLOR)
	slider.add_theme_stylebox_override(&"slider", track)
	slider.add_theme_stylebox_override(&"grabber_area", _bar(FILL_COLOR))
	slider.add_theme_stylebox_override(&"grabber_area_highlight", _bar(FILL_COLOR))
	var handle := MFarmUiArt.texture("ui_handle")
	slider.add_theme_icon_override(&"grabber", handle)
	slider.add_theme_icon_override(&"grabber_highlight", handle)
	slider.add_theme_icon_override(&"grabber_disabled", handle)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(1)
	focus.border_color = MFarmUiArt.FOCUS_COLOR
	focus.anti_aliasing = false
	slider.add_theme_stylebox_override(&"focus", focus)
	slider.value_changed.connect(setter)
	MFarmUiArt.place(content, slider, Vector2(left, floorf(middle_y - SLIDER_SIZE.y / 2)))
	return slider

# The old track: a rounded bar half the slider's height.
static func _bar(color: Color) -> StyleBoxFlat:
	var bar := StyleBoxFlat.new()
	bar.bg_color = color
	bar.set_corner_radius_all(3)
	bar.anti_aliasing = false
	bar.content_margin_top = 5
	bar.content_margin_bottom = 5
	return bar

func _build_settings(content: Control) -> void:
	music_slider = _volume(content, "Music", "Background Music", 50, GameSettings.set_music_volume)
	sounds_slider = _volume(content, "Sounds", "Sounds", 95, GameSettings.set_sounds_volume)
	settings_button = _sheet_button(content, "MoreSettings", "More Settings", 129)

func _build_rest(content: Control) -> void:
	resume_button = _sheet_button(content, "Resume", "Back to Game", 35.5)
	title_button = _sheet_button(content, "ReturnTitle", "Back to Title", 80.5)
	quit_button = _sheet_button(content, "Quit", "Quit Game", 125.5)

func _build_saves(content: Control) -> void:
	save_button = _sheet_button(content, "Save", "Save Game", 58)
	load_button = _sheet_button(content, "Load", "Load Game", 103)
