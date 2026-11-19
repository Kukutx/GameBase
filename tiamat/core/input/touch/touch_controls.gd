class_name TouchControlsService
extends CanvasLayer

## The controls of a touchscreen, drawn over the game while the player plays
## by touch (`InputPrompts.using_touch`): a stick at the lower left that walks
## (`TouchStick`), a button at the lower right for each control the game marks
## `ControlAction.touch_button` (`TouchButton`), and a button that goes back as
## Android's back button does (`go_back()`): a pause button at the left edge
## in play, a close button at the top right over a menu.
##
## What shows follows who holds the controls (`InputLock`):
## - in play, with nothing open (the scene has a `PauseMenu`): the stick while
##   something walks with the move controls (a node in `MOVER_GROUP`, as every
##   `TopDownPlayer` is), the game's buttons, and the corner button, which
##   pauses;
## - in a minigame: what it asks for (`MiniGame.get_touch_actions()`,
##   `uses_touch_stick()`), and the corner button, which cancels;
## - under a menu, a dialogue or a dialog window: only the corner button, which
##   cancels (closes the menu), since the menu is tapped itself.
## Elsewhere (the title) nothing shows. A finger on a control is the
## control's alone: neither its touch nor the mouse click the engine makes of
## it reaches the game.
##
## Android's back button is `go_back()` too, the game told not to quit on it
## (`application/config/quit_on_go_back`, which `tools/link.js` turns off);
## with nothing to close or pause, as on the title, the scene goes back a step
## if it has one to go back (a `go_back() -> bool` of the current scene, as
## `GameTitleBase` has), and the game quits when it has none.
##
## The HUD keeps clear of the controls that show (`get_covered_rects()`,
## `layout_changed`): a HUD line with a `TouchClearance` draws back from them.
##
## The engine makes mouse events of the first finger only. While that finger
## holds a control (a thumb on the stick), a second finger that taps beside
## the controls makes them here instead (`FINGER_MOUSE_DEVICE`), so the player
## taps a field, a slot or a person while walking.

## The controls that show, or where they sit, changed.
signal layout_changed

## Above the minigames (`MiniGameHostService.LAYER`) and the menus.
const LAYER := 110
## The group of the nodes that walk with the move controls; the stick shows
## while one is in the tree.
const MOVER_GROUP := &"touch_mover"
## The action that closes what is open, and the one that pauses.
const CANCEL_ACTION := &"ui_cancel"
const PAUSE_ACTION := &"pause"
## The device of the mouse events a second finger makes while the first
## holds a control; read as a finger's, like the engine's own
## (`InputPromptService.is_from_finger()`).
const FINGER_MOUSE_DEVICE := -8
## How often, in seconds, the controls look whether the screen's clear part
## moved (`safe_rect()`): a phone turned over keeps its size but takes its
## notch to the other side.
const SAFE_AREA_CHECK := 0.5
## The most buttons a game's controls get.
const MAX_BUTTONS := 5
## Sizes against the height of the view, at the normal touch size
## (`GameSettings.get_touch_scale()`).
const STICK_RADIUS := 0.13
const BUTTON_RADIUS := 0.085
const CORNER_RADIUS := 0.06
const MARGIN := 0.05
## How far down the view the pause button sits, at its left edge.
const PAUSE_HEIGHT := 0.4
## Where the buttons after the first sit around it, in its radii: left, up and
## left, up, then further left and up (mirrored while the player has the
## stick at the right, `GameSettings.touch_stick_right`).
const BUTTON_PLACES: Array[Vector2] = [Vector2(-2.3, 0.0), Vector2(-1.7, -1.7), Vector2(0.0, -2.3), Vector2(-4.4, 0.2), Vector2(-3.6, -2.4)]

var _stick: TouchStick
var _corner: TouchButton
var _buttons: Array[TouchButton] = []
# The actions of `_buttons`, in order.
var _button_actions: Array[StringName] = []
# Touch index -> the control (a TouchStick or TouchButton) it pressed.
var _fingers: Dictionary[int, Control] = {}
# What shows: {"stick": bool, "actions": Array[StringName], "back": StringName}.
var _shown: Dictionary = {}
var _applied := false
# The game's touch actions (`game_touch_actions()`), until the controls change.
var _game_actions: Array[StringName] = []
var _game_actions_known := false
# The finger whose touches go on as mouse events (`FINGER_MOUSE_DEVICE`), or
# -1; and where it last was, in the view.
var _mouse_finger := -1
var _mouse_at := Vector2.ZERO
# The clear part of the screen the controls were last placed in, and the
# time to the next look at it.
var _laid_out_safe := Rect2()
var _safe_check_in := 0.0

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stick = TouchStick.new()
	_stick.name = "Stick"
	add_child(_stick)
	_corner = TouchButton.new()
	_corner.name = "Back"
	add_child(_corner)
	get_viewport().size_changed.connect(_layout)
	GameSettings.controls_changed.connect(func() -> void: _game_actions_known = false)
	# The player's size, side and opacity of the controls.
	GameSettings.changed.connect(_layout)
	_show({})

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_release_all()

func _process(delta: float) -> void:
	_show(_wanted())
	_safe_check_in -= delta
	if visible and _safe_check_in <= 0.0:
		_safe_check_in = SAFE_AREA_CHECK
		if safe_rect() != _laid_out_safe:
			_layout()

## Goes back, as Android's back button does: closes what is open (a menu, a
## dialogue, a minigame, a dialog window) with the cancel action, pauses play,
## or, with neither, has the scene go back a step (a title's other page back
## to its first) and quits when it has no step to go back.
func go_back() -> void:
	if not back_step():
		get_tree().quit()

## Goes back as `go_back()` does, short of quitting: false when there is
## nothing to close, pause or go back to, where going back quits.
func back_step() -> bool:
	var action := back_action()
	if action.is_empty():
		var scene := get_tree().current_scene
		return scene != null and scene.has_method(&"go_back") and bool(scene.call(&"go_back"))
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	return true

## What going back presses now: `CANCEL_ACTION` while something is open,
## `PAUSE_ACTION` in play, else nothing.
func back_action() -> StringName:
	if InputLock.is_locked() or _has_open_window():
		return CANCEL_ACTION
	if _in_play() and InputMap.has_action(PAUSE_ACTION):
		return PAUSE_ACTION
	return &""

## Whether the device plays by touch, so the settings offer the size and the
## side of the touch controls: it has a touchscreen, is a phone or a tablet,
## or the player touched it.
static func is_offered() -> bool:
	return DisplayServer.is_touchscreen_available() or InputPromptService.starts_on_touch() or InputPrompts.using_touch

## Whether the touch controls show now.
func is_showing() -> bool:
	return not _shown.is_empty()

## The actions of the buttons that show, in order.
func get_shown_actions() -> Array[StringName]:
	return _button_actions.duplicate() if is_showing() else []

## Where the controls that show sit, in the view's coordinates: the stick's,
## each button's and the corner button's square. Empty while none shows.
func get_covered_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not is_showing():
		return rects
	var controls: Array[Control] = [_stick, _corner]
	controls.append_array(_buttons)
	for control: Control in controls:
		if control.visible:
			rects.append(control.get_rect())
	return rects

## The stick, for tests that drag it.
func get_stick() -> TouchStick:
	return _stick

## The controls of the running game that have a button on a touchscreen.
static func game_touch_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for control: ControlAction in GameSettings.bindings.get_controls():
		if control.touch_button and not TouchStick.MOVE_ACTIONS.has(control.action) and control.action != PAUSE_ACTION:
			result.append(control.action)
	return result.slice(0, MAX_BUTTONS)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _fingers.has(drag.index):
			_fingers[drag.index].call(&"drag", drag.index, drag.position)
			get_viewport().set_input_as_handled()
		elif drag.index == _mouse_finger:
			_send_mouse_motion(drag.position)
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		# The click the engine makes of the first finger: the control's too.
		if _fingers.has(0) or _control_at((event as InputEventMouse).position) != null:
			get_viewport().set_input_as_handled()

func _on_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		var control := _control_at(touch.position)
		if control == null:
			# Beside the controls, a finger the engine makes no mouse of
			# while the first holds one.
			if _mouse_finger < 0 and touch.index != 0 and _fingers.has(0):
				_send_mouse_motion(touch.position)
				_mouse_finger = touch.index
				_send_mouse_button(true)
			return
		_fingers[touch.index] = control
		control.call(&"press", touch.index, touch.position)
		get_viewport().set_input_as_handled()
	elif _fingers.has(touch.index):
		var control: Control = _fingers[touch.index]
		_fingers.erase(touch.index)
		control.call(&"lift", touch.index)
		get_viewport().set_input_as_handled()
	elif touch.index == _mouse_finger:
		_send_mouse_motion(touch.position)
		_lift_mouse_finger()

# The control that shows under `point`, or null.
func _control_at(point: Vector2) -> Control:
	if not is_showing():
		return null
	if _corner.visible and _corner.reaches(point):
		return _corner
	for button: TouchButton in _buttons:
		if button.visible and button.reaches(point):
			return button
	if _stick.visible and _stick.reaches(point):
		return _stick
	return null

# What should show now, as `_shown` holds it; {} for nothing.
func _wanted() -> Dictionary:
	if not InputPrompts.using_touch:
		return {}
	var back := back_action()
	if InputLock.get_top_reason() == MiniGameHostService.LOCK_REASON:
		var minigame := MiniGameHost.get_active()
		if minigame != null:
			return {"stick": minigame.uses_touch_stick(), "actions": minigame.get_touch_actions(), "back": back}
	if back == CANCEL_ACTION:
		var none: Array[StringName] = []
		return {"stick": false, "actions": none, "back": back}
	if back == PAUSE_ACTION:
		if not _game_actions_known:
			_game_actions = game_touch_actions()
			_game_actions_known = true
		var walks := get_tree().get_first_node_in_group(MOVER_GROUP) != null
		return {"stick": walks, "actions": _game_actions, "back": back}
	return {}

func _show(wanted: Dictionary) -> void:
	if _applied and wanted == _shown:
		return
	_applied = true
	_shown = wanted
	visible = not wanted.is_empty()
	_stick.visible = bool(wanted.get("stick", false))
	if not _stick.visible:
		_stick.release()
		_drop_fingers(_stick)
	var actions: Array[StringName] = []
	actions.assign(wanted.get("actions", []))
	if actions != _button_actions:
		_set_buttons(actions)
	var back := StringName(wanted.get("back", &""))
	_corner.visible = not back.is_empty()
	if _corner.action != back:
		_corner.release()
		_corner.action = back
		_corner.sign_shown = TouchButton.Sign.PAUSE if back == PAUSE_ACTION else TouchButton.Sign.BACK
	if not visible:
		_release_all()
	_layout()

func _set_buttons(actions: Array[StringName]) -> void:
	for button: TouchButton in _buttons:
		button.release()
		_drop_fingers(button)
		# Gone at once, so the new button of the same action takes its name
		# (`Button_<action>`) and none is left waiting to be freed.
		remove_child(button)
		button.free()
	_buttons.clear()
	_button_actions = actions.duplicate()
	for action: StringName in actions:
		var button := TouchButton.new()
		button.name = "Button_%s" % action
		button.action = action
		button.label = GameSettings.bindings.get_label(action)
		add_child(button)
		_buttons.append(button)

# A finger still on `control`, which hides or goes, touches nothing more: its
# moves and its lift reach what is under it.
func _drop_fingers(control: Control) -> void:
	for index: int in _fingers.keys():
		if _fingers[index] == control:
			_fingers.erase(index)

func _send_mouse_motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = FINGER_MOUSE_DEVICE
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _mouse_finger >= 0 else 0
	motion.position = _to_window(at)
	motion.global_position = motion.position
	motion.relative = motion.position - _to_window(_mouse_at)
	_mouse_at = at
	_send(motion)

func _send_mouse_button(pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.device = FINGER_MOUSE_DEVICE
	button.button_index = MOUSE_BUTTON_LEFT
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	button.pressed = pressed
	button.position = _to_window(_mouse_at)
	button.global_position = button.position
	_send(button)

func _lift_mouse_finger() -> void:
	if _mouse_finger < 0:
		return
	_mouse_finger = -1
	_send_mouse_button(false)

# Sent once the event at hand is done, as the engine's own come.
func _send(event: InputEvent) -> void:
	Input.parse_input_event.call_deferred(event)

# A point of the view in the window, where the engine's events are.
func _to_window(at: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * at

func _release_all() -> void:
	_lift_mouse_finger()
	_fingers.clear()
	if _stick != null:
		_stick.release()
	if _corner != null:
		_corner.release()
	for button: TouchButton in _buttons:
		button.release()

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var unit := view.y
	var margin := unit * MARGIN
	# Placed in the part of the screen a notch or rounded corners leave clear.
	var clear := safe_rect()
	_laid_out_safe = clear
	var left := clear.position.x + margin
	var right := clear.end.x - margin
	var top := clear.position.y + margin
	var bottom := clear.end.y - margin
	# The player's size, and the side the stick takes (the buttons the other).
	var size_scale := GameSettings.get_touch_scale()
	var stick_right := GameSettings.touch_stick_right
	_stick.radius = unit * STICK_RADIUS * size_scale
	var stick_x := right - _stick.radius * 1.15 if stick_right else left + _stick.radius * 1.15
	_place(_stick, Vector2(stick_x, bottom - _stick.radius * 1.15), _stick.radius)
	_corner.radius = unit * CORNER_RADIUS * size_scale
	# In play the HUD fills the top corners, so the pause button sits at the
	# edge above the stick; over a menu the close button takes the top right
	# corner, as a menu's close button does.
	if _corner.sign_shown == TouchButton.Sign.PAUSE:
		var pause_x := right - _corner.radius if stick_right else left + _corner.radius
		_place(_corner, Vector2(pause_x, view.y * PAUSE_HEIGHT), _corner.radius)
	else:
		_place(_corner, Vector2(right - _corner.radius, top + _corner.radius), _corner.radius)
	var radius := unit * BUTTON_RADIUS * size_scale
	var first_x := left + radius * 1.2 if stick_right else right - radius * 1.2
	var first := Vector2(first_x, bottom - radius * 1.2)
	for index: int in _buttons.size():
		var button := _buttons[index]
		button.radius = radius if index > 0 else radius * 1.2
		var place := Vector2.ZERO if index == 0 else BUTTON_PLACES[index - 1]
		# The places lie toward the middle, so they mirror when the buttons
		# take the left.
		if stick_right:
			place.x = -place.x
		_place(button, first + place * radius, button.radius)
	# The player's opacity, over each control's own (a held control draws
	# stronger).
	var controls: Array[Control] = [_stick, _corner]
	controls.append_array(_buttons)
	for control: Control in controls:
		control.modulate.a = GameSettings.touch_opacity
	layout_changed.emit()

## The part of the view that the screen's notch, rounded corners and system
## bars leave clear (`DisplayServer.get_display_safe_area()`), in the view's
## coordinates; the whole view where the screen tells nothing useful.
func safe_rect() -> Rect2:
	var full := get_viewport().get_visible_rect()
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return full
	var window := Rect2(Vector2(safe.position - DisplayServer.window_get_position()), Vector2(safe.size))
	var clear := get_tree().root.get_final_transform().affine_inverse() * window
	clear = clear.intersection(full)
	# A clear part that leaves too little is a screen that says something
	# else (a window half off it): the whole view then.
	if clear.size.x < full.size.x * 0.6 or clear.size.y < full.size.y * 0.6:
		return full
	return clear

func _place(control: Control, center: Vector2, radius: float) -> void:
	control.size = Vector2.ONE * radius * 2.0
	control.position = center - control.size * 0.5

func _in_play() -> bool:
	return get_tree().get_first_node_in_group(PauseMenu.MENU_ID) != null and not WorldTravel.is_traveling()

func _has_open_window() -> bool:
	return not get_tree().root.get_embedded_subwindows().is_empty()
