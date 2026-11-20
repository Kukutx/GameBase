extends RefCounted

## Whether a menu fits the game's view and holds the focus, for the tests of
## every layer's menus.

const ScreenFit := preload("res://tiamat/core/test/screen_fit.gd")

## Has `tree` show the game in a view of `size`, one of the views it is laid
## out in (`ScreenFit.view_sizes()`), as a phone shows its own: the menus a
## test opens next lay out in it. A test that calls it gives the game's own
## back (`size` zero) once it is done.
static func show_view(tree: SceneTree, size := Vector2.ZERO) -> void:
	tree.root.content_scale_size = Vector2i(ScreenFit.base_size() if size == Vector2.ZERO else size)

## The visible controls under `root` that reach outside `view`, each with its
## rect; only the outermost one of a branch is named. What a ScrollContainer
## holds may scroll; the container itself must fit. A dialog is a window of
## its own (`find_window_overflow`).
static func find_overflow(root: Node, view: Rect2) -> PackedStringArray:
	var problems := PackedStringArray()
	_check(root, view.grow(0.5), problems)
	return problems

## The visible controls under `menu` that reach outside the view
## (`find_overflow()`), in each view the game is laid out in
## (`ScreenFit.view_sizes()`): the view it shows, then each other, a phone's
## smaller one among them, the menu laid out in it a frame later, named with
## the view. The view the game showed is back once it returns.
static func find_overflow_in_views(menu: Node) -> PackedStringArray:
	var tree := menu.get_tree()
	var problems := find_overflow(menu, menu.get_viewport().get_visible_rect())
	var shown := tree.root.content_scale_size
	var sizes := ScreenFit.view_sizes()
	for size: Vector2 in sizes.slice(1):
		show_view(tree, size)
		# Containers sort their children on the frame after a change.
		await tree.process_frame
		await tree.process_frame
		for line: String in find_overflow(menu, menu.get_viewport().get_visible_rect()):
			problems.append("%s in the view %s" % [line, size])
	if sizes.size() > 1:
		tree.root.content_scale_size = shown
		await tree.process_frame
		await tree.process_frame
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
