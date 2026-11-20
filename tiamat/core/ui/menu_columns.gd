class_name MenuColumns
extends Node

## Lays a menu's list beside the words it shows of the entry in focus while
## the view is wide enough, and above them in a narrower view (a 4:3
## tablet's), so the words of a long entry (a dish and all it does) read
## whole beside a list that keeps its height.
##
## A child of the `BoxContainer` that holds the list and the words: it turns
## that box (`BoxContainer.vertical`), widens the menu's panel (the nearest
## `PanelContainer` above it, centred on the view) to `wide_width`, and lets
## each wrapping `Label` of the box run up to `wide_lines` lines side by side,
## `narrow_lines` under the list. The list and the words split the width by
## their `size_flags_stretch_ratio`.

## The panel's width side by side.
@export var wide_width := 460.0
## The most lines the words take beside the list.
@export var wide_lines := 6
## The most lines the words take under the list.
@export var narrow_lines := 2
## The room the panel keeps from each side of the view.
const MARGIN := 10.0

# The panel's width as the scene lays it out, for a narrow view.
var _narrow_width := 0.0

func _ready() -> void:
	var panel := _panel()
	if panel != null:
		_narrow_width = panel.offset_right - panel.offset_left
	get_viewport().size_changed.connect(_fit)
	_fit()

## Whether the list and the words stand side by side.
func is_side_by_side() -> bool:
	var box := get_parent() as BoxContainer
	return box != null and not box.vertical

## Lays the menu out for a view `view_width` wide.
func fit_to(view_width: float) -> void:
	var box := get_parent() as BoxContainer
	if box == null:
		return
	var wide := view_width >= wide_width + 2.0 * MARGIN
	box.vertical = not wide
	var panel := _panel()
	if panel != null and _narrow_width > 0.0:
		var width := wide_width if wide else _narrow_width
		panel.offset_left = -width / 2.0
		panel.offset_right = width / 2.0
	for child: Node in box.get_children():
		var words := child as Label
		if words != null and words.autowrap_mode != TextServer.AUTOWRAP_OFF:
			words.max_lines_visible = wide_lines if wide else narrow_lines

func _fit() -> void:
	fit_to(get_viewport().get_visible_rect().size.x)

# The menu's panel, the nearest `PanelContainer` above, or null.
func _panel() -> PanelContainer:
	var node := get_parent()
	while node != null and not node is PanelContainer:
		node = node.get_parent()
	return node as PanelContainer
