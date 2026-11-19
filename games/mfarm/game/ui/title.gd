extends GameTitleBase

## MFarm's title screen, the old game's menu: a sheet of paper in the middle
## of the screen, with three coloured tabs down its right edge that bring
## their sheet to the top.
##
## - 开始 (blue): a card for each save slot. A card continues the game saved
##   there, or starts a new game in it when it holds none (这个世界还没有开始,
##   梦还没开始); its little × deletes what it holds, after asking.
## - 说明 (yellow): the keys.
## - 退出 (red): quits. The old tab only showed the first sheet again: the
##   game's ExitGame was never wired to it. A web page has no 退出.
##
## The first sheet shows the title in the old brush font and the version. The
## gear in the corner opens the settings, as it does in play, and a line
## under the paper says what went wrong or what was done. Esc goes back to the
## first sheet. Everything is laid out at the old canvas's own size.

enum Sheet { KEYS, SLOTS, TITLE }

const PAPER_SIZE := Vector2(243, 161)
const TEXT_COLOR := Color(0.196, 0.196, 0.196)
const TITLE_COLOR := Color(0.667, 0.392, 0.176)
const STATUS_COLOR := Color(0.95, 0.88, 0.72)
const TITLE_FONT: Font = preload("res://game/unity/fonts/Gongfan.ttf")
## Each sheet's tab: its art, its word and where its top left sits on the
## paper (the old tabs stood 115 pixels right of the middle and 60 above or
## below it).
const TABS := {
	Sheet.KEYS: ["ui_paper_06", "Help", Vector2(218, 74)],
	Sheet.SLOTS: ["ui_paper_07", "Play", Vector2(218, 14)],
	Sheet.TITLE: ["ui_paper_05", "Quit", Vector2(218, 134)],
}
const TAB_SIZE := Vector2(38, 14)
const CARD_WIDTH := 148.0
## The slots' column: 30 pixels above and below it, 10 between the cards.
const CARD_MARGIN := 30.0
const CARD_GAP := 10.0
const VERSION_TEXT := "Copyright StarCat@ Version %s"

var paper: Control
## Each sheet's page, by Sheet: its content shows while it is on top.
var sheets: Dictionary[Sheet, Control] = {}
var contents: Dictionary[Sheet, Control] = {}
var tabs: Dictionary[Sheet, Button] = {}
var cards: Array[Button] = []
var card_lines: Array[Label] = []
var delete_buttons: Array[Button] = []
var settings_button: Button
var title_label: Label
var version_label: Label
var keys_label: Label
var status_label: Label
var shown := Sheet.TITLE

func _ready() -> void:
	super()
	_build()
	show_sheet(Sheet.TITLE)
	_refresh_slot_ui()
	tabs[Sheet.SLOTS].grab_focus()

## Brings `sheet` to the top, as the old game's tabs did.
func show_sheet(sheet: Sheet) -> void:
	shown = sheet
	paper.move_child(sheets[sheet], -1)
	for each: Sheet in contents:
		contents[each].visible = each == sheet

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and shown != Sheet.TITLE and not settings_menu.visible:
		get_viewport().set_input_as_handled()
		show_sheet(Sheet.TITLE)
		tabs[Sheet.SLOTS].grab_focus()

func _on_tab_pressed(sheet: Sheet) -> void:
	if sheet == Sheet.TITLE and can_quit():
		_quit()
		return
	show_sheet(sheet)
	if sheet == Sheet.SLOTS and not cards.is_empty():
		cards[0].grab_focus()

## The two lines a card shows: when and where the saved game is, or that the
## slot holds nothing yet (or a save this version cannot open).
func card_text(summary: Dictionary) -> String:
	if bool(summary.get("exists", false)):
		var minute := int(summary["minute_of_day"])
		var when := "%s %02d:%02d" % [MFarmTimePanel.date_text(int(summary["day"]), tr("%d.%02d.%02d")), minute / 60, minute % 60]
		var where := tr(String(summary.get("location_name", "")))
		if bool(summary.get("autosave", false)):
			where = tr("Autosave · %s") % where
		return "%s\n%s" % [when, where]
	if bool(summary.get("unreadable", false)):
		return "%s\n%s" % [tr("This save cannot be opened"), tr("Click to begin anew")]
	return "%s\n%s" % [tr("This world has not begun"), tr("The dream has not started")]

func _refresh_slot_ui() -> void:
	for index: int in cards.size():
		var summary := SaveManager.get_slot_summary(index + 1)
		card_lines[index].text = card_text(summary)
		delete_buttons[index].visible = SaveManager.has_files(index + 1)

func _set_buttons_disabled(value: bool) -> void:
	for button: Button in cards + delete_buttons + tabs.values() + [settings_button]:
		button.disabled = value

func _show_status(text: String) -> void:
	status_label.text = text

func _on_settings_closed() -> void:
	super()
	settings_button.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not cards.is_empty():
		_refresh_slot_ui()

func _build() -> void:
	paper = Control.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MFarmUiArt.centre(paper, PAPER_SIZE, 0.0)
	add_child(paper)
	paper.add_child(MFarmUiArt.image(MFarmUiArt.texture("ui_paper_01"), PAPER_SIZE))
	# The old menu's order: the keys at the bottom, the title on top.
	for sheet: Sheet in [Sheet.KEYS, Sheet.SLOTS, Sheet.TITLE]:
		_build_sheet(sheet)
	_build_title(contents[Sheet.TITLE])
	_build_slots(contents[Sheet.SLOTS])
	_build_keys(contents[Sheet.KEYS])
	tabs[Sheet.TITLE].visible = can_quit()

	settings_button = MFarmUiArt.button("ui_button_set", Vector2(9, 9))
	settings_button.name = "Settings"
	settings_button.tooltip_text = "Settings"
	settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_button.position = Vector2(-12, 3)
	settings_button.pressed.connect(_open_settings)
	add_child(settings_button)

	status_label = MFarmUiArt.label("", 8, STATUS_COLOR)
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MFarmUiArt.centre(status_label, Vector2(PAPER_SIZE.x + 120, 24), PAPER_SIZE.y / 2 + 24)
	add_child(status_label)

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
	tab.pressed.connect(_on_tab_pressed.bind(sheet))
	MFarmUiArt.place(page, tab, tab_art[2])
	sheets[sheet] = page
	contents[sheet] = content
	tabs[sheet] = tab

func _build_title(content: Control) -> void:
	title_label = MFarmUiArt.label(String(ProjectSettings.get_setting("application/config/name", "")), 35, TITLE_COLOR)
	title_label.add_theme_font_override(&"font", TITLE_FONT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size = Vector2(160, 45)
	MFarmUiArt.place(content, title_label, Vector2(41.5, 48))
	version_label = MFarmUiArt.label(VERSION_TEXT % String(ProjectSettings.get_setting("application/config/version", "")), 7, TEXT_COLOR)
	version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version_label.size = Vector2(160, 30)
	MFarmUiArt.place(content, version_label, Vector2(41.5, 120.5))

func _build_slots(content: Control) -> void:
	var count := GameSaveManager.get_slot_count()
	var height := floorf((PAPER_SIZE.y - 2 * CARD_MARGIN - CARD_GAP * (count - 1)) / count)
	for index: int in count:
		var card := MFarmUiArt.button("ui_paper_02", Vector2(CARD_WIDTH, height))
		card.name = "Slot%d" % (index + 1)
		card.pressed.connect(open_slot.bind(index + 1))
		MFarmUiArt.place(content, card, Vector2(floorf((PAPER_SIZE.x - CARD_WIDTH) / 2), CARD_MARGIN + index * (height + CARD_GAP)))
		var lines := MFarmUiArt.label("", 10, TEXT_COLOR)
		lines.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lines.add_theme_constant_override(&"line_spacing", -1)
		lines.size = card.size
		card.add_child(lines)
		var delete := Button.new()
		delete.name = "Delete"
		delete.flat = true
		delete.text = "×"
		delete.tooltip_text = "Delete Save"
		delete.add_theme_font_override(&"font", MFarmUiArt.FONT)
		# Unifont's own size, so the cross stays sharp.
		delete.add_theme_font_size_override(&"font_size", 16)
		for color_name: StringName in [&"font_color", &"font_focus_color", &"font_pressed_color"]:
			delete.add_theme_color_override(color_name, TITLE_COLOR)
		delete.add_theme_color_override(&"font_hover_color", Color(0.85, 0.3, 0.2))
		delete.add_theme_stylebox_override(&"focus", card.get_theme_stylebox(&"focus"))
		delete.size = Vector2(10, 16)
		delete.pressed.connect(delete_slot.bind(index + 1))
		MFarmUiArt.place(card, delete, Vector2(CARD_WIDTH - 13, floorf((height - 16) / 2)))
		cards.append(card)
		card_lines.append(lines)
		delete_buttons.append(delete)

func _build_keys(content: Control) -> void:
	keys_label = MFarmUiArt.label("WASD to walk\nCheats: T speeds up time | G next day", 10, TEXT_COLOR)
	keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The old text stood 1.8 lines apart.
	keys_label.add_theme_constant_override(&"line_spacing", 8)
	keys_label.size = Vector2(200, 40)
	MFarmUiArt.place(content, keys_label, (PAPER_SIZE - keys_label.size) / 2)
