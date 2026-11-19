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

## The menu's name: its group and the reason of its lock.
var menu_id: StringName

func _init(id: StringName) -> void:
	menu_id = id
	add_to_group(id)
	# It works while the world it pauses stands still.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

## A button for one entry of a menu's list (a recipe, an item to buy): its
## text wraps at the menu's width instead of widening the menu past the view.
static func list_button(text := "") -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
