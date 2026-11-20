extends RefCounted

## Whether a game's screens, its HUD and its menus, keep to the edges of a
## view wider than the one they were laid out in, for the test of every
## game's screens (`test_screens_fit.gd`). A phone held sideways is about
## 20:9, and a game that keeps its height (`window/stretch/aspect`
## `keep_height` or `expand`) shows it a view that much wider: what sat at a
## corner must still sit at that corner, a line across the view must still
## reach both sides, and what sat in the middle must still sit in the
## middle. Anchors do this (a right corner's `anchor_left` and `anchor_right`
## at 1, the middle's at 0.5); offsets alone keep a control where it was.
##
##     const ScreenFit := preload("res://tiamat/core/test/screen_fit.gd")
##     assert_eq(await ScreenFit.find_drift(self, HUD), PackedStringArray())

## How much wider than tall a phone held sideways shows the game.
const PHONE_ASPECT := 20.0 / 9.0
## How far, in pixels of the view, a part may drift from where it belongs.
const TOLERANCE := 1.0
## A line across the view keeps each side's gap under this share of its width.
const LINE_GAP := 0.05
## How far, in pixels of the view, two parts may overlap each way: a shared
## edge or a font's spare line is no overlap.
const OVERLAP := 2.0
## A part in the middle has gaps that differ by less than this share.
const MIDDLE_SKEW := 0.05

## Whether a wider screen shows the game a wider view, rather than bars
## beside it.
static func widens() -> bool:
	var mode := String(ProjectSettings.get_setting("display/window/stretch/mode", "disabled"))
	var aspect := String(ProjectSettings.get_setting("display/window/stretch/aspect", "keep"))
	return mode != "disabled" and aspect in ["keep_height", "expand"]

## The size the game's screens are laid out in (`window/size/viewport_*`).
static func base_size() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))

## Every size the game's screens are laid out in: its own (`base_size()`),
## then each it names for a kind of device, as a phone's
## (`window/size/viewport_width.mobile` and `viewport_height.mobile`; a side
## it leaves out keeps the game's own).
static func view_sizes() -> Array[Vector2]:
	var base := base_size()
	var sizes: Array[Vector2] = [base]
	for property: Dictionary in ProjectSettings.get_property_list():
		var name := String(property.name)
		for side: String in ["width", "height"]:
			var prefix := "display/window/size/viewport_%s." % side
			if not name.begins_with(prefix):
				continue
			var feature := name.trim_prefix(prefix)
			var size := Vector2(_side(base, "width", feature), _side(base, "height", feature))
			if not sizes.has(size):
				sizes.append(size)
	return sizes

## The size of the view the game shows a phone: the one it names for phones
## (`window/size/viewport_width.mobile` and `viewport_height.mobile`), else
## its own.
static func phone_size() -> Vector2:
	var base := base_size()
	return Vector2(_side(base, "width", "mobile"), _side(base, "height", "mobile"))

## The texts of the screen `scene`, shown in a view of `size`, that a phone
## shows too small to read (`ReadableText.min_font_size()`), each named by
## its path from the screen with its size and the least it needs. What is
## hidden counts: a closed menu opens.
static func find_small_text(test: Node, scene: PackedScene, size: Vector2) -> PackedStringArray:
	var view := await _host(test, scene, size)
	var screen := view.get_child(0)
	var least := ReadableText.min_font_size(size)
	var problems := PackedStringArray()
	for node: Node in screen.find_children("*", "Control", true, false):
		var control := node as Control
		var drawn := ReadableText.font_size_of(control)
		if _has_text(control) and drawn < least:
			problems.append("%s: %d px, %d at least" % [screen.get_path_to(control), drawn, least])
	view.free()
	return problems

## The scenes under `folders` that are screens: a `CanvasLayer`, or a control
## stretched over the whole view, at their root. A `test` folder is passed by.
static func find_screens(folders: PackedStringArray) -> PackedStringArray:
	var found := PackedStringArray()
	for folder: String in folders:
		_find_scenes(folder, found)
	var screens := PackedStringArray()
	for path: String in found:
		var state := (load(path) as PackedScene).get_state()
		var kind := state.get_node_type(0)
		if kind == &"":
			continue
		if ClassDB.is_parent_class(kind, &"CanvasLayer") or (ClassDB.is_parent_class(kind, &"Control") and _fills_view(state)):
			screens.append(path)
	return screens

## The parts of the screen `scene` that drift from their side, or from the
## middle, when the view widens from `base` (the game's own, by default) to a
## phone's shape; each named with where it sat and where it went. A part is
## each control the screen's layer holds, seen as the box of what it draws; a
## control that fills the view (a menu's backdrop) or a layer of its own (a
## menu on its own `CanvasLayer`) is no part, the controls it holds are, named
## by their path from the screen.
##
## A part that shows must lie inside the view it was laid out in (a closed
## menu is measured but not held to it). A part with both gaps
## to the view's sides small (`LINE_GAP`) is a line
## across the view: it must reach as near both sides as before. One with its
## gaps alike (`MIDDLE_SKEW`) sits in the middle: it must keep its distance
## from the middle (a line in the middle may do either). Any other part keeps
## its gap to the nearer side. `test` hosts the views while they lay out.
static func find_drift(test: Node, scene: PackedScene, base := Vector2.ZERO) -> PackedStringArray:
	if base == Vector2.ZERO:
		base = base_size()
	var wide := Vector2(roundf(base.y * PHONE_ASPECT), base.y)
	var shown := {}
	var at_base := await _boxes(test, scene, base, shown)
	var at_wide := await _boxes(test, scene, wide, {})
	var problems := PackedStringArray()
	for part: String in at_base:
		if not at_wide.has(part):
			continue
		var before: Rect2 = at_base[part]
		var after: Rect2 = at_wide[part]
		if shown.has(part) and not Rect2(Vector2.ZERO, base).grow(TOLERANCE).encloses(before):
			problems.append("%s: %s reaches outside the view %s" % [part, before, base])
			continue
		var wanted := _places(before, after.size.x, base.x, wide.x)
		var fits := false
		for place: Vector2 in wanted:
			if absf(after.position.x - place.x) <= TOLERANCE and absf(after.end.x - place.y) <= TOLERANCE:
				fits = true
		if not fits:
			problems.append("%s: %s in %s, %s in %s (wanted from x %.0f to %.0f)" % [part, before, base, after, wide, wanted[0].x, wanted[0].y])
	return problems

# Where, from x to x, a part that sat at `before` in a view `base` wide may sit
# in a view `wide` wide, now `width` wide itself; the likeliest first.
static func _places(before: Rect2, width: float, base: float, wide: float) -> Array[Vector2]:
	var left := before.position.x
	var right := base - before.end.x
	var line := left <= base * LINE_GAP and right <= base * LINE_GAP
	var middle := absf(left - right) <= base * MIDDLE_SKEW
	var places: Array[Vector2] = []
	if line:
		places.append(Vector2(left, wide - right))
	if middle:
		var centre := before.get_center().x + (wide - base) / 2.0
		places.append(Vector2(centre - width / 2.0, centre + width / 2.0))
	if places.is_empty():
		if left < right:
			places.append(Vector2(left, left + width))
		else:
			places.append(Vector2(wide - right - width, wide - right))
	return places

# Part name -> the box of what each part of the screen draws, the screen
# shown in a view of `size`; the parts that show are added to `shown`.
static func _boxes(test: Node, scene: PackedScene, size: Vector2, shown: Dictionary) -> Dictionary:
	var view := await _host(test, scene, size)
	var screen := view.get_child(0)
	var boxes := {}
	_add_parts(screen, "", Rect2(Vector2.ZERO, size), boxes)
	for part: String in boxes:
		if _shows(screen.get_node(part)):
			shown[part] = true
	# Gone at once: the test that measured it may end on this frame.
	view.free()
	return boxes

# A view of `size` under `test` that shows the screen `scene`, laid out.
static func _host(test: Node, scene: PackedScene, size: Vector2) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(size)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	test.add_child(view)
	view.add_child(scene.instantiate())
	await test.get_tree().process_frame
	await test.get_tree().process_frame
	return view

# Whether `control` shows text: a label's or a button's, or a field's, which
# the player types into.
static func _has_text(control: Control) -> bool:
	if control is Label:
		return not (control as Label).text.is_empty()
	if control is Button:
		return not (control as Button).text.is_empty()
	if control is RichTextLabel:
		return not (control as RichTextLabel).text.is_empty()
	return ReadableText.font_size_of(control) > 0

# Adds to `boxes` the parts among the children of `holder`, named from `path`.
static func _add_parts(holder: Node, path: String, whole: Rect2, boxes: Dictionary) -> void:
	for child: Node in holder.get_children():
		var part := path + String(child.name)
		if child is CanvasLayer:
			_add_parts(child, part + "/", whole, boxes)
		elif child is Control:
			var control := child as Control
			var own := control.get_global_rect()
			if own.position.is_equal_approx(whole.position) and own.size.is_equal_approx(whole.size):
				_add_parts(control, part + "/", whole, boxes)
				continue
			var box := _box(control)
			if box.has_area() or box.size.x > 0.0:
				boxes[part] = box

# Whether `node` shows, no control or layer above it hidden.
static func _shows(node: Node) -> bool:
	while node != null:
		if (node is CanvasItem and not (node as CanvasItem).visible) or (node is CanvasLayer and not (node as CanvasLayer).visible):
			return false
		node = node.get_parent()
	return true

# The box around `control` and every control it holds and shows, in the view.
static func _box(control: Control) -> Rect2:
	var box := control.get_global_rect()
	var found := box.has_area()
	for child: Node in control.get_children():
		if child is Control and (child as Control).visible and not (child as Control).top_level:
			var inner := _box(child)
			if inner.has_area():
				box = inner if not found else box.merge(inner)
				found = true
	return box if found else Rect2()

# The `side` of the view the game names for `feature`, or the game's own.
static func _side(base: Vector2, side: String, feature: String) -> float:
	var own := base.x if side == "width" else base.y
	return float(ProjectSettings.get_setting("display/window/size/viewport_%s.%s" % [side, feature], own))

static func _find_scenes(folder: String, found: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		if not sub.begins_with(".") and sub != "test":
			_find_scenes(folder.path_join(sub), found)
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "tscn":
			found.append(folder.path_join(file))

# Whether the root of the scene `state` is anchored to the view's four sides.
static func _fills_view(state: SceneState) -> bool:
	var anchors := {}
	for index: int in state.get_node_property_count(0):
		anchors[state.get_node_property_name(0, index)] = state.get_node_property_value(0, index)
	return is_equal_approx(float(anchors.get(&"anchor_right", 0.0)), 1.0) and is_equal_approx(float(anchors.get(&"anchor_bottom", 0.0)), 1.0) \
		and is_zero_approx(float(anchors.get(&"anchor_left", 0.0))) and is_zero_approx(float(anchors.get(&"anchor_top", 0.0)))

## The pairs of parts (see `find_drift()`) of the screen `scene`, shown in a
## view of `size`, that both show and overlap by more than `OVERLAP` each way:
## two lines of a HUD laid over each other, whose texts run into each other as
## soon as one grows (the money, a message), or a corner label under a menu.
## A part hidden until it is needed (a closed menu) is left out.
static func find_overlaps(test: Node, scene: PackedScene, size: Vector2) -> PackedStringArray:
	var shown := {}
	var boxes := await _boxes(test, scene, size, shown)
	var parts: Array = boxes.keys().filter(func(part: String) -> bool: return shown.has(part))
	var problems := PackedStringArray()
	for first: int in parts.size():
		for second: int in range(first + 1, parts.size()):
			var a: Rect2 = boxes[parts[first]]
			var b: Rect2 = boxes[parts[second]]
			var cut := a.intersection(b)
			if cut.size.x > OVERLAP and cut.size.y > OVERLAP:
				problems.append("%s %s overlaps %s %s" % [parts[first], a, parts[second], b])
	return problems
