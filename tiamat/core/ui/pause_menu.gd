class_name PauseMenu
extends MenuLayer

## The pause menu every game's locations share: the core's `pause` control
## (Esc, Start) opens it over the paused world, to resume, save, load, change
## the settings, read again the tips the player has seen (`TipsMenu`, offered
## once one has shown), see the achievements (`AchievementsMenu`, offered in a
## game that has any), read the pages the modules add (`add_page()`: what the
## player carries, how far their skills are) and the bonuses that change their
## stats now (`GameStats.describe_current()`: a boon's, a perk's, a buff's
## added up), each offered while it has anything to say, return to the title
## screen (the game's main scene) or quit;
## `pause` or `ui_cancel` closes it. It also opens when the window loses focus
## (`GameSettings.pause_on_focus_loss`): the player turns to another app, or
## to another tab of the browser, which tells the game only that its page lost
## the focus. And it opens when the gamepad in use disconnects
## (`InputPrompts.gamepad_disconnected`), over the world or over a minigame,
## which stands still under it, and `quick_load` asks here before a load
## throws away the progress since the last save. A load here takes the
## player's own save, not a newer autosave, so going back to what they saved
## stays one step; with no save of their own, it takes the autosave.
##
## A game may lay the menu out its own way, as MFarm's old paper menu does.
## Its scene names the controls `%Resume`, `%Save`, `%Load`, `%Settings`,
## `%ReturnTitle`, `%Quit` (buttons) and `%Status` (a label) wherever it puts
## them, `%Tips` where it offers the tips, `%Achievements` where it offers
## the achievements and `%Pages` (a container) where it offers the pages, or a
## script extending this one
## sets `resume_button` and the others
## before it calls `super()` in `_ready()`, and overrides `_focus_on_open()`
## and `_set_main_buttons_disabled()` for controls of its own. The settings
## menu and the questions are the scene's own `SettingsMenu`, `ConfirmLoad`,
## `ConfirmTitle` and `ConfirmQuit` when it has them, or are made here.

## The menu's id: its group and the reason of its lock, held while the game
## is paused for the player (`GameSession` counts no time played then).
const MENU_ID := &"pause_menu"
## The control that opens and closes the menu (`core/input/controls/pause.tres`).
const PAUSE_ACTION := &"pause"

const SETTINGS_MENU := preload("res://tiamat/core/ui/settings_menu.tscn")
const TIPS_MENU := preload("res://tiamat/core/ui/tips_menu.tscn")
const ACHIEVEMENTS_MENU := preload("res://tiamat/core/ui/achievements_menu.tscn")
## The page of the bonuses, which the core adds.
const BONUSES_PAGE := &"bonuses"

## The pages the menu offers, by id: each its button's text (a translation
## key), its place among them and the function that gives its lines.
static var _pages: Dictionary[StringName, Array] = {}

## The pages of `add_page()` this menu leaves out: a game whose own menu shows
## what they would.
@export var hidden_pages: Array[StringName] = []

var resume_button: Button
var save_button: Button
var load_button: Button
var settings_button: Button
var title_button: Button
var quit_button: Button
## The button that opens the tips, or null for a layout that offers none.
var tips_button: Button
## The button that opens the achievements, or null for a layout that offers
## none.
var achievements_button: Button
## Where the buttons of the pages go, or null for a layout that offers none.
var pages_row: Container
var status_label: Label
var settings_menu: SettingsMenu
var tips_menu: TipsMenu
var achievements_menu: AchievementsMenu
var confirm_load: ConfirmationDialog
var confirm_title: ConfirmationDialog
var confirm_quit: ConfirmationDialog

# Whether the load this menu started is under way.
var _loading := false
# The buttons of the pages offered now, by page id.
var _page_buttons: Dictionary[StringName, Button] = {}

## Adds a page the menu offers while `lines`, a `func() -> PackedStringArray`
## of lines translated already, gives any: a button `title` (a translation
## key) among the menu's pages, lower `order` first, that shows the lines over
## the menu. A module adds its pages when it installs (the items module what
## the player carries); adding an id again replaces its page.
static func add_page(id: StringName, title: String, order: int, lines: Callable) -> void:
	_pages[id] = [title, order, lines]

## The ids of the pages added, in their order.
static func get_page_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_pages.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var a_order := int(_pages[a][1])
		var b_order := int(_pages[b][1])
		return a_order < b_order or (a_order == b_order and String(a) < String(b)))
	return ids

## The lines page `id` shows now, or none for no such page.
static func get_page_lines(id: StringName) -> PackedStringArray:
	var page: Array = _pages.get(id, [])
	return PackedStringArray((page[2] as Callable).call()) if not page.is_empty() else PackedStringArray()

static func _bonus_lines() -> PackedStringArray:
	return GameStats.describe_current()

func _init() -> void:
	super(MENU_ID)
	if not _pages.has(BONUSES_PAGE):
		add_page(BONUSES_PAGE, "Bonuses", 100, _bonus_lines)

func _ready() -> void:
	_find_controls()
	# A web page is left by closing its tab.
	quit_button.visible = not OS.has_feature("web")
	# A phone has no desktop to quit to.
	if OS.has_feature("mobile"):
		if quit_button.text == "Quit to Desktop":
			quit_button.text = "Quit Game"
		if confirm_quit.title == "Quit to Desktop":
			confirm_quit.title = "Quit Game"
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_save_game)
	load_button.pressed.connect(request_load)
	settings_button.pressed.connect(_open_settings)
	title_button.pressed.connect(confirm_title.popup_centered)
	quit_button.pressed.connect(confirm_quit.popup_centered)
	settings_menu.closed.connect(_on_settings_closed)
	if tips_button != null:
		tips_button.pressed.connect(_open_side_menu.bind(tips_menu))
		tips_menu.closed.connect(_on_side_menu_closed.bind(tips_button))
	if achievements_button != null:
		achievements_button.pressed.connect(_open_side_menu.bind(achievements_menu))
		achievements_menu.closed.connect(_on_side_menu_closed.bind(achievements_button))
	confirm_load.confirmed.connect(_load_game)
	confirm_title.confirmed.connect(_return_to_title)
	confirm_quit.confirmed.connect(_quit)
	for dialog: ConfirmationDialog in [confirm_load, confirm_title, confirm_quit]:
		dialog.canceled.connect(_on_dialog_canceled.bind(dialog))
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)
	InputPrompts.gamepad_disconnected.connect(_on_gamepad_disconnected)
	# Its small print reads on a phone, in a narrow view as in a wide one.
	ReadableText.raise(self)

# The layout's controls, the settings menu and the questions.
func _find_controls() -> void:
	resume_button = resume_button if resume_button != null else get_node(^"%Resume") as Button
	save_button = save_button if save_button != null else get_node(^"%Save") as Button
	load_button = load_button if load_button != null else get_node(^"%Load") as Button
	settings_button = settings_button if settings_button != null else get_node(^"%Settings") as Button
	title_button = title_button if title_button != null else get_node(^"%ReturnTitle") as Button
	quit_button = quit_button if quit_button != null else get_node(^"%Quit") as Button
	status_label = status_label if status_label != null else get_node(^"%Status") as Label
	tips_button = tips_button if tips_button != null else get_node_or_null(^"%Tips") as Button
	if tips_button != null:
		tips_menu = _side_menu(^"TipsMenu", TIPS_MENU) as TipsMenu
	achievements_button = achievements_button if achievements_button != null else get_node_or_null(^"%Achievements") as Button
	if achievements_button != null:
		achievements_menu = _side_menu(^"AchievementsMenu", ACHIEVEMENTS_MENU) as AchievementsMenu
	pages_row = pages_row if pages_row != null else get_node_or_null(^"%Pages") as Container
	settings_menu = get_node_or_null(^"SettingsMenu") as SettingsMenu
	if settings_menu == null:
		settings_menu = SETTINGS_MENU.instantiate() as SettingsMenu
		settings_menu.name = "SettingsMenu"
		add_child(settings_menu)
	confirm_load = _question(&"ConfirmLoad", "Load Game", "Unsaved progress will be lost. Load your last save?", "Load")
	confirm_title = _question(&"ConfirmTitle", "Return to Title", "Unsaved progress will be lost. Return to the title screen?", "Return to Title")
	confirm_quit = _question(&"ConfirmQuit", "Quit to Desktop", "Unsaved progress will be lost. Quit the game?", "Quit")

# The scene's own menu `node_name` that opens over this one, or one made of
# `scene`.
func _side_menu(node_name: NodePath, scene: PackedScene) -> Node:
	var menu := get_node_or_null(node_name)
	if menu == null:
		menu = scene.instantiate()
		menu.name = String(node_name)
		add_child(menu)
	return menu

# The scene's own question, or a new one with the core's words.
func _question(node_name: StringName, title_text: String, text: String, ok_text: String) -> ConfirmationDialog:
	var dialog := get_node_or_null(NodePath(node_name)) as ConfirmationDialog
	if dialog != null:
		return dialog
	dialog = ConfirmationDialog.new()
	dialog.name = node_name
	dialog.title = title_text
	dialog.dialog_text = text
	dialog.size = Vector2i(300, 100)
	dialog.dialog_autowrap = true
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)
	return dialog

func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT) and is_node_ready() and GameSettings.pause_on_focus_loss and _runs_unwatched():
		open()

func _on_gamepad_disconnected() -> void:
	if _runs_unwatched():
		open()

# Whether play goes on while the player looks away: the world runs, or a
# minigame does over it. A menu or a dialogue on top waits for the player.
func _runs_unwatched() -> bool:
	return not get_tree().paused or InputLock.get_top_reason() == MiniGameHostService.LOCK_REASON

func _unhandled_input(event: InputEvent) -> void:
	var pause := InputMap.has_action(PAUSE_ACTION) and event.is_action_pressed(PAUSE_ACTION)
	var cancel := event.is_action_pressed("ui_cancel")
	var quick_load := event.is_action_pressed("quick_load")
	if not pause and not cancel and not quick_load:
		return
	if settings_menu.visible or _is_side_menu_open() or _is_dialog_open():
		return
	if not visible:
		# Cancel only leaves the menu; something else may hold the input (a
		# menu, a minigame, a travel).
		if (cancel and not pause and not quick_load) or InputLock.is_locked():
			return
		open()
	elif not InputLock.is_top(self):
		return
	elif pause or cancel:
		close()
	if quick_load and visible:
		request_load()
	get_viewport().set_input_as_handled()

## Opens the menu, unless a travel is changing the scene: what the menu
## offers (a load, the title) would race it.
func open() -> void:
	if visible or WorldTravel.is_traveling():
		return
	show_menu()
	status_label.text = ""
	load_button.disabled = not SaveManager.has_save()
	if tips_button != null:
		tips_button.visible = not TipsMenu.seen_hints().is_empty()
	if achievements_button != null:
		achievements_button.visible = AchievementsMenu.has_any()
	_offer_pages()
	_focus_on_open()

## Where the keys and a gamepad start when the menu opens.
func _focus_on_open() -> void:
	resume_button.grab_focus()

func close() -> void:
	if not visible:
		return
	settings_menu.close()
	for menu: Node in [tips_menu, achievements_menu, ChoiceMenu.of(self)]:
		if menu != null:
			menu.call(&"close")
	for dialog: ConfirmationDialog in [confirm_load, confirm_title, confirm_quit]:
		dialog.hide()
	super()

## Asks before loading the player's save (or the autosave, with none of their
## own) over the progress since.
func request_load() -> void:
	if not SaveManager.has_save():
		status_label.text = tr("No save available")
		return
	var autosave := get_load_kind() == GameSaveManager.SaveKind.AUTO
	confirm_load.dialog_text = tr("Unsaved progress will be lost. Load the autosave?") if autosave else tr("Unsaved progress will be lost. Load your last save?")
	confirm_load.popup_centered()

func _is_dialog_open() -> bool:
	return confirm_load.visible or confirm_title.visible or confirm_quit.visible

func _save_game() -> void:
	SaveManager.save_game()
	load_button.disabled = not SaveManager.has_save()

func _load_game() -> void:
	close()
	# Not awaited: a load that succeeds frees this menu with its location.
	_loading = true
	SaveManager.load_game(get_load_kind())

## Which of the slot's saves a load here takes: the player's own, else the
## autosave.
static func get_load_kind() -> GameSaveManager.SaveKind:
	return GameSaveManager.SaveKind.MANUAL if SaveManager.has_save(-1, GameSaveManager.SaveKind.MANUAL) else GameSaveManager.SaveKind.AUTO

func _open_settings() -> void:
	_set_main_buttons_disabled(true)
	settings_menu.open()

func _on_settings_closed() -> void:
	_set_main_buttons_disabled(false)
	load_button.disabled = not SaveManager.has_save()
	if visible:
		settings_button.grab_focus()

## The button of page `id` while the menu offers it, or null.
func get_page_button(id: StringName) -> Button:
	return _page_buttons.get(id)

## Shows page `id` over the menu and gives the list shown, or null when the
## menu does not offer it.
func show_page(id: StringName) -> ChoiceMenu:
	var button: Button = _page_buttons.get(id)
	if button == null:
		return null
	_set_main_buttons_disabled(true)
	var menu := ChoiceMenu.tell(self, String(_pages[id][0]), get_page_lines(id))
	menu.picked.connect(func(_choice: StringName) -> void: _on_side_menu_closed(button), CONNECT_ONE_SHOT)
	return menu

# A button for each page with anything to say, in their order.
func _offer_pages() -> void:
	_page_buttons.clear()
	if pages_row == null:
		return
	for child: Node in pages_row.get_children():
		pages_row.remove_child(child)
		child.queue_free()
	for id: StringName in get_page_ids():
		if hidden_pages.has(id) or get_page_lines(id).is_empty():
			continue
		var button := Button.new()
		button.text = String(_pages[id][0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_page.bind(id))
		pages_row.add_child(button)
		_page_buttons[id] = button
	pages_row.visible = not _page_buttons.is_empty()
	ReadableText.raise(pages_row)

# Whether the tips, the achievements or the bonuses show over the menu.
func _is_side_menu_open() -> bool:
	var bonuses := ChoiceMenu.of(self)
	return (tips_menu != null and tips_menu.visible) or (achievements_menu != null and achievements_menu.visible) or (bonuses != null and bonuses.visible)

func _open_side_menu(menu: CanvasLayer) -> void:
	_set_main_buttons_disabled(true)
	menu.call(&"open")

func _on_side_menu_closed(button: Button) -> void:
	_set_main_buttons_disabled(false)
	load_button.disabled = not SaveManager.has_save()
	if visible:
		button.grab_focus()

func _on_dialog_canceled(dialog: ConfirmationDialog) -> void:
	if not visible:
		return
	if dialog == confirm_load:
		load_button.grab_focus()
	elif dialog == confirm_title:
		title_button.grab_focus()
	else:
		quit_button.grab_focus()

func _return_to_title() -> void:
	if not GameSession.return_to_title():
		status_label.text = tr("Cannot return to the title while the scene changes")

func _quit() -> void:
	get_tree().quit()

func _on_save_completed(_success: bool, message: String) -> void:
	if visible:
		status_label.text = message

func _on_load_completed(success: bool, message: String) -> void:
	if _loading:
		_loading = false
		if not success:
			open()
	if visible:
		status_label.text = message

func _set_main_buttons_disabled(value: bool) -> void:
	resume_button.disabled = value
	save_button.disabled = value
	load_button.disabled = value
	settings_button.disabled = value
	title_button.disabled = value
	quit_button.disabled = value
	for button: Button in [tips_button, achievements_button]:
		if button != null:
			button.disabled = value
	for button: Button in _page_buttons.values():
		button.disabled = value
