extends RefCounted

## Whether a menu fits the game's view, for the tests of every layer's menus.

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
