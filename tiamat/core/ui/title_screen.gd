class_name GameTitleScreen
extends GameTitleBase

## The title screen every game opens on (its main scene) unless it brings its
## own: the game's name, description and version from the project settings,
## its save slots (as many as the game sets, each continuing from the newer of
## its saves) with a button beside them that deletes the one chosen, a new
## game, the settings, the achievements (in a game that has any) and
## quitting, in rows as full as each other (`EvenRows`). Like every menu it
## takes the project's theme (`gui/theme/custom`). What it does with a slot is
## GameTitleBase's; this is how it looks.

@onready var title_label: Label = $Center/Menu/Title
@onready var subtitle_label: Label = $Center/Menu/Subtitle
@onready var version_label: Label = $Center/Menu/Footer/Version
@onready var slot_select: OptionButton = $Center/Menu/SlotRow/SaveSlot
@onready var slot_info: Label = $Center/Menu/SlotInfo
@onready var continue_button: Button = $Center/Menu/Continue
@onready var new_game_button: Button = $Center/Menu/Actions/NewGame
@onready var delete_button: Button = $Center/Menu/SlotRow/DeleteSave
@onready var settings_button: Button = $Center/Menu/Actions/Settings
@onready var achievements_button: Button = $Center/Menu/Actions/Achievements
@onready var quit_button: Button = $Center/Menu/Actions/Quit
@onready var status_label: Label = $Center/Menu/Footer/Status

func _ready() -> void:
	super()
	title_label.text = String(ProjectSettings.get_setting("application/config/name", ""))
	subtitle_label.text = String(ProjectSettings.get_setting("application/config/description", ""))
	subtitle_label.visible = not subtitle_label.text.is_empty()
	version_label.text = GameDiagnosticsService.version_text()
	_build_slot_selector()
	slot_select.item_selected.connect(_on_slot_selected)
	continue_button.pressed.connect(_continue_game)
	new_game_button.pressed.connect(_new_game)
	delete_button.pressed.connect(_delete_save)
	settings_button.pressed.connect(_open_settings)
	achievements_button.pressed.connect(_open_achievements)
	achievements_button.visible = AchievementsMenu.has_any()
	quit_button.pressed.connect(_quit)
	quit_button.visible = can_quit()
	_refresh_slot_ui()
	# Its small print reads on a phone, in a narrow view as in a wide one.
	ReadableText.raise(self)
	(new_game_button if continue_button.disabled else continue_button).grab_focus()

func _build_slot_selector() -> void:
	slot_select.clear()
	var count := GameSaveManager.get_slot_count()
	for slot in range(1, count + 1):
		slot_select.add_item(tr("Save Slot %d") % slot, slot)
	slot_select.select(clampi(SaveManager.active_slot - 1, 0, count - 1))
	SaveManager.select_slot(slot_select.selected + 1)

func _on_slot_selected(index: int) -> void:
	SaveManager.select_slot(index + 1)
	_show_status("")
	_refresh_slot_ui()

func _refresh_slot_ui() -> void:
	var summary := SaveManager.get_slot_summary(SaveManager.active_slot)
	var exists := bool(summary["exists"])
	var unreadable := bool(summary["unreadable"])
	continue_button.disabled = not exists
	delete_button.disabled = not exists and not unreadable
	if exists:
		slot_info.text = GameText.keep_dots(_format_slot_summary(summary))
	else:
		slot_info.text = tr("Holds a save this version cannot open") if unreadable else tr("Empty slot")

func _show_status(text: String) -> void:
	status_label.text = text

func _on_settings_closed() -> void:
	_build_slot_selector()
	super()
	settings_button.grab_focus()

func _on_achievements_closed() -> void:
	super()
	achievements_button.grab_focus()

func _set_buttons_disabled(value: bool) -> void:
	slot_select.disabled = value
	continue_button.disabled = value
	new_game_button.disabled = value
	delete_button.disabled = value
	settings_button.disabled = value
	achievements_button.disabled = value
	quit_button.disabled = value
