class_name MenuLayer
extends CanvasLayer

## A menu over the world, which the core's and the modules' menus extend. It
## stays hidden until it shows (`show_menu()`), pauses the world and holds the
## player's controls while it shows (an `InputLock` lock named `menu_id`,
## given back when the menu leaves the tree), and `ui_cancel` closes it while
## the menu is on top (`InputLock.is_top()`). Its opening and closing are
## told as `GameEvents.menu_opened` and `menu_closed`, which the game's menu
## sounds play on (`GameAudio`). A menu is found by its id as a group:
## `get_tree().get_first_node_in_group(&"shop_menu")`.
##
## A menu passes its id to the constructor (`super(&"shop_menu")` in its
## `_init()`), opens with arguments of its own and then calls `show_menu()`.

## Emitted when the menu closes.
signal closed

## The meta of a list's button that names its entry (a recipe's id), so a list
## rebuilt after a press gives the focus back to the same entry
## (`focused_key()`, `focus_kept()`).
const FOCUS_KEY := &"focus_key"
## The widest and tallest an entry's icon draws in a list (`list_button()`,
## `refill_list()`): a smaller icon keeps its size, a larger one shrinks, so a
## large texture does not make the rows tall.
const LIST_ICON_SIZE := 24

## The menu's name: its group and the reason of its lock.
var menu_id: StringName

func _init(id: StringName) -> void:
	menu_id = id
	add_to_group(id)
	# It works while the world it pauses stands still.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

## A button for one entry of a menu's list (a recipe, an item to buy): its
## text wraps at the menu's width instead of widening the menu past the view,
## after `icon` (the item's, say), if any.
static func list_button(text := "", icon: Texture2D = null) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.icon = icon
	button.add_theme_constant_override(&"icon_max_width", LIST_ICON_SIZE)
	return button

## Gives `control` the focus. In a list that scrolls to the focus (a
## `ScrollContainer` with `follow_focus`), the list then shows it once the
## menu has its size: a menu that just showed, or just built its list, is not
## laid out yet, and a list scrolled to the focus then sits off by a row, its
## top row out of sight. A control the list shows from its top opens the list
## at its top.
static func focus(control: Control) -> void:
	control.grab_focus()
	var scroll := _scroll_of(control)
	if scroll == null:
		return
	await control.get_tree().process_frame
	if not is_instance_valid(control) or not is_instance_valid(scroll) or not control.has_focus():
		return
	var content := scroll.get_child(0) as Control
	var top := control.get_global_rect().position.y - content.get_global_rect().position.y
	if top + control.size.y <= scroll.size.y:
		scroll.scroll_vertical = 0
	else:
		scroll.ensure_control_visible(control)

## What names the entry whose button has the focus in `menu`'s view (its
## `FOCUS_KEY` meta), or null: a menu reads it before it rebuilds its list.
static func focused_key(menu: Node) -> Variant:
	var owner := menu.get_viewport().gui_get_focus_owner() if menu.is_inside_tree() else null
	return owner.get_meta(FOCUS_KEY) if owner != null and owner.has_meta(FOCUS_KEY) else null

## Gives the focus, in a list just rebuilt, back to the button of `buttons`
## whose `FOCUS_KEY` meta is `key`, or, while that one is disabled, to the next
## that is not, else the nearest before it; with no such button, to the first
## not disabled; with none, to `fallback`. So the player who crafts or buys
## stays on the entry they pressed.
static func focus_kept(buttons: Array[Button], key: Variant, fallback: Control) -> void:
	var at := -1
	if key != null:
		for index: int in buttons.size():
			if buttons[index].has_meta(FOCUS_KEY) and buttons[index].get_meta(FOCUS_KEY) == key:
				at = index
				break
	var order: Array = range(buttons.size()) if at < 0 else range(at, buttons.size()) + range(at - 1, -1, -1)
	for index: int in order:
		if not buttons[index].disabled:
			focus(buttons[index])
			return
	focus(fallback)

## Fills `list` with `rows`, each {"text": what the entry reads, "key": what
## names it, its metadata, and an optional "icon" drawn before the text},
## keeping selected the entry whose key was, or, once it is gone, the entry
## now in its place: a list that changes as the player moves its items (a
## chest, a shipping bin) keeps their pick. An icon larger than
## `LIST_ICON_SIZE` makes the list draw its icons at that size, unless the
## list has a `fixed_icon_size` of its own.
static func refill_list(list: ItemList, rows: Array[Dictionary]) -> void:
	var selected := list.get_selected_items()
	var kept_index := int(selected[0]) if not selected.is_empty() else -1
	var kept_key: Variant = list.get_item_metadata(kept_index) if kept_index >= 0 else null
	list.clear()
	for row: Dictionary in rows:
		var icon := row.get("icon") as Texture2D
		if icon != null and list.fixed_icon_size == Vector2i.ZERO and maxi(icon.get_width(), icon.get_height()) > LIST_ICON_SIZE:
			list.fixed_icon_size = Vector2i(LIST_ICON_SIZE, LIST_ICON_SIZE)
		var index := list.add_item(String(row["text"]), icon)
		list.set_item_metadata(index, row["key"])
		if kept_key != null and row["key"] == kept_key:
			kept_index = index
	if kept_index >= 0 and list.item_count > 0:
		list.select(mini(kept_index, list.item_count - 1))
		list.ensure_current_is_visible()

## Sets the name at the start of each row under `root` (a row: a box whose
## first part is a `Label`, as "Music" before its slider) in by as much as
## `switch`, a button of the same menu, sets in its words, so the names of
## the rows and the words of the switches between them start in one line in
## whatever theme the game draws with.
static func line_up_names(root: Node, switch: Button) -> void:
	var inset := switch.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)
	for row: Node in root.find_children("*", "BoxContainer", true, false):
		var label: Label = row.get_child(0) as Label if row.get_child_count() > 0 else null
		if label == null or (row as BoxContainer).vertical:
			continue
		var room := StyleBoxEmpty.new()
		room.content_margin_left = inset
		label.add_theme_stylebox_override(&"normal", room)

# The nearest list around `control` that scrolls to the focus, or null.
static func _scroll_of(control: Control) -> ScrollContainer:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer and (node as ScrollContainer).follow_focus:
			return node as ScrollContainer
		node = node.get_parent()
	return null

## Whether the menu shows.
func is_open() -> bool:
	return visible

## Shows the menu over the paused world, holding the player's controls.
func show_menu() -> void:
	var opened := not visible
	visible = true
	InputLock.lock(menu_id, true, self)
	if opened:
		GameEvents.menu_opened.emit(menu_id)

## Hides the menu and gives the controls back.
func close() -> void:
	if not visible:
		return
	visible = false
	InputLock.unlock(menu_id)
	GameEvents.menu_closed.emit(menu_id)
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and InputLock.is_top(self) and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
