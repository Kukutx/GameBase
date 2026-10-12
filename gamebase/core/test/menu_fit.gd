extends RefCounted

## Whether a menu fits the game's view and holds the focus, for the tests of
## every layer's menus.

## The visible controls under `root` that reach outside `view`, each with its
## rect; only the outermost one of a branch is named. What a ScrollContainer
## holds may scroll; the container itself must fit. A dialog is a window of
## its own (`find_window_overflow`).
static func find_overflow(root: Node, view: Rect2) -> PackedStringArray:
	var problems := PackedStringArray()
	_check(root, view.grow(0.5), problems)
	return problems

## The dialog's rect when it reaches outside `view`, else "".
static func find_window_overflow(window: Window, view: Rect2) -> String:
	var rect := Rect2(Vector2(window.position), Vector2(window.size))
	return "" if view.grow(0.5).encloses(rect) else "%s %s" % [window.name, rect]

## Why the focus is not where an open `menu` needs it, or "": a menu opens with
## a control of its own in focus, never a disabled button, so the keys and a
## gamepad work it at once and never reach the screen behind it.
static func find_focus_problem(menu: Node) -> String:
	var focus := menu.get_viewport().gui_get_focus_owner()
	if focus == null:
		return "%s has nothing in focus" % menu.name
	if focus != menu and not menu.is_ancestor_of(focus):
		return "%s lets the focus out to %s" % [menu.name, focus.get_path()]
	if focus is BaseButton and (focus as BaseButton).disabled:
		return "%s has its disabled %s in focus" % [menu.name, focus.name]
	return ""

static func _check(node: Node, view: Rect2, problems: PackedStringArray) -> void:
	if node is Window or (node is CanvasItem and not (node as CanvasItem).is_visible_in_tree()):
		return
	if node is Control:
		var rect := (node as Control).get_global_rect()
		if not view.encloses(rect):
			problems.append("%s %s" % [node.name if not node.is_inside_tree() else String(node.get_path()), rect])
			return
		if node is ScrollContainer:
			return
	for child: Node in node.get_children():
		_check(child, view, problems)
