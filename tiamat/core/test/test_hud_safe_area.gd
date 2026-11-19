extends GutTest

## A HUD keeps clear of a phone's camera and rounded corners
## (`HudSafeArea`): what keeps to a side moves in from it by the strip the
## screen leaves unsafe there, what sits in the middle or fills the view
## stays, and all goes back when the screen is clear again.

var _hud: CanvasLayer
var _safe_area: HudSafeArea
var _view: Rect2

func before_each() -> void:
	_view = get_viewport().get_visible_rect()
	_hud = CanvasLayer.new()
	add_child_autofree(_hud)

func test_each_control_moves_in_from_the_sides_it_keeps_to() -> void:
	var left := _control(Vector4(0, 0, 0, 0), Vector4(8, 6, 108, 22))
	var right := _control(Vector4(1, 0, 1, 0), Vector4(-108, 6, -8, 22))
	var across := _control(Vector4(0, 0, 1, 0), Vector4(8, 24, -8, 40))
	var middle := _control(Vector4(0.5, 0, 0.5, 0), Vector4(-50, 40, 50, 56))
	var bottom := _control(Vector4(0, 1, 1, 1), Vector4(8, -24, -8, -8))
	var backdrop := _control(Vector4(0, 0, 1, 1), Vector4.ZERO)
	var controls: Array[Control] = [left, right, across, middle, bottom, backdrop]
	_add_safe_area()
	var laid_out := _rects(controls)
	# A phone with its camera at the left and a rounded strip at the bottom.
	_safe_area.fit_to(Rect2(30, 0, _view.size.x - 40, _view.size.y - 6))
	assert_almost_eq(left.get_global_rect().position.x, laid_out[0].position.x + 30.0, 0.01, "the left one moves right of the camera")
	assert_almost_eq(right.get_global_rect().end.x, laid_out[1].end.x - 10.0, 0.01, "the right one moves in from the right strip")
	assert_almost_eq(across.get_global_rect().position.x, laid_out[2].position.x + 30.0, 0.01, "a line across draws in from the left")
	assert_almost_eq(across.get_global_rect().end.x, laid_out[2].end.x - 10.0, 0.01, "and from the right")
	assert_eq(middle.get_global_rect(), laid_out[3], "the middle stays")
	assert_almost_eq(bottom.get_global_rect().end.y, laid_out[4].end.y - 6.0, 0.01, "the bottom line rises off the bottom strip")
	assert_eq(backdrop.get_global_rect(), laid_out[5], "what fills the view stays")
	assert_eq(_safe_area.get_moved(left), Vector4(30, 0, 30, 0))
	# Turned over: the camera at the right.
	_safe_area.fit_to(Rect2(0, 0, _view.size.x - 30, _view.size.y))
	assert_almost_eq(left.get_global_rect().position.x, laid_out[0].position.x, 0.01, "the left one goes back")
	assert_almost_eq(right.get_global_rect().end.x, laid_out[1].end.x - 30.0, 0.01, "the right one moves left of the camera")
	_safe_area.fit_to(_view)
	assert_eq(_rects(controls), laid_out, "a clear screen puts all back")
	assert_eq(_safe_area.get_moved(right), Vector4.ZERO)

func test_a_computer_s_window_moves_nothing() -> void:
	var right := _control(Vector4(1, 0, 1, 0), Vector4(-108, 6, -8, 22))
	var laid_out := right.get_global_rect()
	_add_safe_area()
	await wait_process_frames(2)
	_safe_area.call("_refresh")
	assert_eq(right.get_global_rect(), laid_out)
	assert_eq(_safe_area.get_moved(right), Vector4.ZERO)

func test_leaving_puts_the_hud_back() -> void:
	var left := _control(Vector4(0, 0, 0, 0), Vector4(8, 6, 108, 22))
	_add_safe_area()
	_safe_area.fit_to(Rect2(30, 0, _view.size.x - 30, _view.size.y))
	_hud.remove_child(_safe_area)
	_safe_area.free()
	assert_almost_eq(left.offset_left, 8.0, 0.01)

func _add_safe_area() -> void:
	_safe_area = HudSafeArea.new()
	_hud.add_child(_safe_area)

# A label anchored at `anchors` (left, top, right, bottom) with `offsets`.
func _control(anchors: Vector4, offsets: Vector4) -> Label:
	var label := Label.new()
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.offset_left = offsets.x
	label.offset_top = offsets.y
	label.offset_right = offsets.z
	label.offset_bottom = offsets.w
	_hud.add_child(label)
	return label

func _rects(controls: Array[Control]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for control: Control in controls:
		rects.append(control.get_global_rect())
	return rects
