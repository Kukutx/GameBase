class_name MenuLayer
extends CanvasLayer

## A menu over the world, which the core's and the modules' menus extend. It
## stays hidden until it shows (`show_menu()`), pauses the world and holds the
## player's controls while it shows (an `InputLock` lock named `menu_id`,
## given back when the menu leaves the tree), and `ui_cancel` closes it while
## the menu is on top (`InputLock.is_top()`). A menu is found by its id as a
## group:
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

## Whether the menu shows.
func is_open() -> bool:
	return visible

## Shows the menu over the paused world, holding the player's controls.
func show_menu() -> void:
	visible = true
	InputLock.lock(menu_id, true, self)

## Hides the menu and gives the controls back.
func close() -> void:
	if not visible:
		return
	visible = false
	InputLock.unlock(menu_id)
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and InputLock.is_top(self) and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
