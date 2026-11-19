class_name JianghuPet
extends Node2D

## The hero on the desk: picks what to do by turns (cultivate, practise the
## sword, stroll, look about; sleep at night by the player's clock), says a
## line in a bubble, and can be clicked or picked up and carried. Where a
## stroll or a carry goes is the desk's to decide (`strolled`, `dragged`),
## since on the desktop it moves the window and in a window it moves the hero.

signal clicked
signal drag_started
## The pointer moved `screen_delta` pixels of the screen while carrying.
signal dragged(screen_delta: Vector2)
signal drag_ended
## The hero wants to walk `distance` pixels of the view (negative: left).
signal strolled(distance: float)

enum Activity { MEDITATE, PRACTICE, WALK, IDLE, SLEEP }

## Pixels of the view per second while strolling.
const WALK_SPEED := 22.0
const DRAG_THRESHOLD := 6.0
const CHEER_SECONDS := 1.6
## The local hours the hero sleeps between.
const NIGHT_FROM := 23
const NIGHT_UNTIL := 6
## The part of the hero a click lands on, around the feet.
const HIT_RECT := Rect2(-26, -92, 52, 94)

@onready var figure: JianghuHeroFigure = $Figure
@onready var bubble: PanelContainer = $Bubble
@onready var bubble_label: Label = $Bubble/Text

var activity := Activity.MEDITATE
var _activity_left := 8.0
var _cheer_left := 0.0
var _bubble_left := 0.0
var _pressed := false
var _dragging := false
var _press_screen := Vector2.ZERO
var _last_screen := Vector2.ZERO

func _ready() -> void:
	bubble.visible = false
	_apply_pose()

func _process(delta: float) -> void:
	_bubble_left -= delta
	if bubble.visible and _bubble_left <= 0.0:
		bubble.visible = false
	if _dragging:
		return
	if _cheer_left > 0.0:
		_cheer_left -= delta
		if _cheer_left <= 0.0:
			_apply_pose()
		return
	_activity_left -= delta
	if _activity_left <= 0.0:
		_choose_activity()
	if activity == Activity.WALK:
		strolled.emit(WALK_SPEED * delta * figure.facing)

## Whether a point of the view is on the hero.
func is_hit(view_point: Vector2) -> bool:
	return HIT_RECT.has_point(to_local(view_point))

## The hero's clickable area in the view.
func get_hit_rect() -> Rect2:
	return get_global_transform() * HIT_RECT

## Shows a line in the bubble for a while.
func say(text: String, seconds := 4.0) -> void:
	bubble_label.text = text
	bubble.visible = true
	bubble.reset_size()
	bubble.position = Vector2(-bubble.size.x / 2.0, HIT_RECT.position.y - bubble.size.y - 4.0)
	_bubble_left = seconds

func cheer() -> void:
	_cheer_left = CHEER_SECONDS
	figure.pose = JianghuHeroFigure.Pose.CHEER

## Turns the hero round at an edge it walked into.
func turn_back() -> void:
	figure.facing = -figure.facing

func set_aura(color: Color) -> void:
	figure.aura = color

func is_dragging() -> bool:
	return _dragging

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed and is_hit(get_global_mouse_position()):
			_pressed = true
			_press_screen = Vector2(DisplayServer.mouse_get_position())
			_last_screen = _press_screen
			get_viewport().set_input_as_handled()
		elif not button.pressed and _pressed:
			_pressed = false
			get_viewport().set_input_as_handled()
			if _dragging:
				_dragging = false
				_apply_pose()
				drag_ended.emit()
			else:
				clicked.emit()
	elif event is InputEventMouseMotion and _pressed:
		var screen := Vector2(DisplayServer.mouse_get_position())
		if not _dragging and screen.distance_to(_press_screen) >= DRAG_THRESHOLD:
			_dragging = true
			figure.pose = JianghuHeroFigure.Pose.HELD
			drag_started.emit()
		if _dragging:
			dragged.emit(screen - _last_screen)
			_last_screen = screen
		get_viewport().set_input_as_handled()

func _choose_activity() -> void:
	var hour := int(Time.get_datetime_dict_from_system().hour)
	if hour >= NIGHT_FROM or hour < NIGHT_UNTIL:
		activity = Activity.SLEEP
		_activity_left = 30.0
	else:
		var roll := randf()
		if roll < 0.45:
			activity = Activity.MEDITATE
			_activity_left = randf_range(18.0, 40.0)
		elif roll < 0.7:
			activity = Activity.PRACTICE
			_activity_left = randf_range(6.0, 12.0)
		elif roll < 0.9:
			activity = Activity.WALK
			_activity_left = randf_range(4.0, 9.0)
			if randf() < 0.5:
				turn_back()
		else:
			activity = Activity.IDLE
			_activity_left = randf_range(3.0, 6.0)
	_apply_pose()

func _apply_pose() -> void:
	match activity:
		Activity.MEDITATE:
			figure.pose = JianghuHeroFigure.Pose.MEDITATE
		Activity.PRACTICE:
			figure.pose = JianghuHeroFigure.Pose.PRACTICE
		Activity.WALK:
			figure.pose = JianghuHeroFigure.Pose.WALK
		Activity.SLEEP:
			figure.pose = JianghuHeroFigure.Pose.SLEEP
		_:
			figure.pose = JianghuHeroFigure.Pose.IDLE
