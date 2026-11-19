class_name RtsBattleField
extends Control

## The field of a command battle as the player sees it (`RtsBattleGame`): the
## ground and its obstacles, scaled to fit the field's size, the units with
## their health, the units the player selected, the blows and shots between
## units, where the player's last orders went, the box the player drags and
## the cursor of the keys and the gamepad. It reports where on the field, in
## its pixels, the player clicks (Shift adds, a double click takes the kind),
## drags a box or right clicks.

signal clicked(point: Vector2, additive: bool, double: bool)
signal box_dragged(rect: Rect2, additive: bool)
signal right_clicked(point: Vector2)

## How long the line of a blow or a shot shows.
const FLASH_SECONDS := 0.18
## How long the mark of an order shows.
const MARK_SECONDS := 0.5
## How far, in pixels on the screen, a press moves before it drags a box.
const DRAG_PIXELS := 4.0

@export var ground_color := Color(0.33, 0.43, 0.29)
@export var obstacle_color := Color(0.27, 0.27, 0.3)
@export var outside_color := Color(0.08, 0.09, 0.1)
@export var player_side_color := Color(0.95, 0.92, 0.78)
@export var foe_side_color := Color(0.6, 0.14, 0.14)
@export var selection_color := Color(0.5, 1.0, 0.55)
@export var health_color := Color(0.4, 0.85, 0.45)
@export var foe_health_color := Color(1.0, 0.45, 0.4)
@export var flash_color := Color(1.0, 0.95, 0.7)
@export var move_mark_color := Color(0.5, 1.0, 0.55)
@export var attack_mark_color := Color(1.0, 0.45, 0.4)
@export var box_color := Color(0.5, 1.0, 0.55, 0.9)
@export var cursor_color := Color(1.0, 1.0, 1.0, 0.95)

var battle: RtsBattle
## The units the player selected, ringed.
var selection: Array[RtsUnit] = []
## Where the cursor of the keys and the gamepad is, in pixels of the field.
var cursor := Vector2.ZERO
var show_cursor := false

var _flashes: Array[Dictionary] = []
var _marks: Array[Dictionary] = []
var _press_at := Vector2.INF
var _drag_to := Vector2.ZERO
var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## Shows `battle_to_show` and follows what happens in it.
func show_battle(battle_to_show: RtsBattle) -> void:
	battle = battle_to_show
	_flashes.clear()
	_marks.clear()
	battle.unit_attacked.connect(_on_unit_attacked)
	queue_redraw()

## How many pixels on the screen a pixel of the field takes: whole when the
## field fits that way.
func get_zoom() -> float:
	if battle == null:
		return 1.0
	var fit := minf(size.x / battle.size.x, size.y / battle.size.y)
	return maxf(floorf(fit) if fit >= 1.0 else fit, 0.01)

## Where the field's top left corner is on the screen.
func get_origin() -> Vector2:
	return ((size - battle.size * get_zoom()) * 0.5).floor()

## The point of the field at `point` on the screen, which may lie off it.
func to_field(point: Vector2) -> Vector2:
	return (point - get_origin()) / get_zoom()

## The point on the screen of `point` on the field.
func to_screen(point: Vector2) -> Vector2:
	return get_origin() + point * get_zoom()

## Shows for a moment where an order sent units: to attack, or to move.
func mark(point: Vector2, attack := false) -> void:
	_marks.append({"point": point, "attack": attack, "age": 0.0})

## Whether the lines of blows and the marks of orders have faded.
func is_settled() -> bool:
	return _flashes.is_empty() and _marks.is_empty()

func _process(delta: float) -> void:
	if battle == null:
		return
	_age(_flashes, FLASH_SECONDS, delta)
	_age(_marks, MARK_SECONDS, delta)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if battle == null:
		return
	var button := event as InputEventMouseButton
	if button != null:
		_on_mouse_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		# The mouse points for itself.
		show_cursor = false
	if motion != null and _press_at != Vector2.INF and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag_to = motion.position
		_dragging = _dragging or _drag_to.distance_to(_press_at) > DRAG_PIXELS
		accept_event()

func _on_mouse_button(button: InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		accept_event()
		right_clicked.emit(to_field(button.position))
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if button.pressed and button.double_click:
		# The release that follows is no click of its own.
		_press_at = Vector2.INF
		clicked.emit(to_field(button.position), button.shift_pressed, true)
	elif button.pressed:
		_press_at = button.position
		_drag_to = button.position
		_dragging = false
	elif _press_at != Vector2.INF:
		if _dragging:
			box_dragged.emit(Rect2(to_field(_press_at), Vector2.ZERO).expand(to_field(button.position)), button.shift_pressed)
		else:
			clicked.emit(to_field(button.position), button.shift_pressed, false)
		_press_at = Vector2.INF
		_dragging = false

func _draw() -> void:
	if battle == null:
		return
	var zoom := get_zoom()
	var origin := get_origin()
	draw_rect(Rect2(Vector2.ZERO, size), outside_color)
	draw_rect(Rect2(origin, battle.size * zoom), ground_color)
	for obstacle: Rect2 in battle.navigation.obstacles:
		draw_rect(Rect2(origin + obstacle.position * zoom, obstacle.size * zoom), obstacle_color)
	for entry: Dictionary in _marks:
		var age: float = entry["age"]
		var color: Color = attack_mark_color if bool(entry["attack"]) else move_mark_color
		color.a = 1.0 - age / MARK_SECONDS
		draw_arc(to_screen(entry["point"] as Vector2), (4.0 - age / MARK_SECONDS * 2.0) * zoom, 0.0, TAU, 16, color, 1.0)
	for unit: RtsUnit in battle.units:
		if unit.is_alive():
			_draw_unit(unit, zoom)
	for entry: Dictionary in _flashes:
		var color := flash_color
		color.a = 1.0 - float(entry["age"]) / FLASH_SECONDS
		draw_line(to_screen(entry["from"] as Vector2), to_screen(entry["to"] as Vector2), color, maxf(zoom * 0.5, 1.0))
	if _dragging:
		var box := Rect2(_press_at, Vector2.ZERO).expand(_drag_to)
		draw_rect(box, Color(box_color, box_color.a * 0.15))
		draw_rect(box, box_color, false, 1.0)
	if show_cursor:
		var at := to_screen(cursor)
		var arm := maxf(4.0 * zoom, 4.0)
		draw_line(at - Vector2(arm, 0.0), at + Vector2(arm, 0.0), cursor_color, 1.0)
		draw_line(at - Vector2(0.0, arm), at + Vector2(0.0, arm), cursor_color, 1.0)

func _draw_unit(unit: RtsUnit, zoom: float) -> void:
	var at := to_screen(unit.position)
	var radius := unit.data.radius * zoom
	var ring := player_side_color if battle.is_on_player_side(unit) else foe_side_color
	if selection.has(unit):
		draw_arc(at, radius + maxf(zoom * 1.5, 1.5), 0.0, TAU, 20, selection_color, 1.0)
	if unit.data.texture != null:
		draw_texture_rect(unit.data.texture, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
	else:
		draw_circle(at, radius, unit.data.color)
		draw_arc(at, radius, 0.0, TAU, 16, ring, maxf(zoom * 0.75, 1.0))
		var font := get_theme_default_font()
		var font_size := maxi(roundi(radius * 1.3), 6)
		var initial := TranslationServer.translate(unit.data.display_name).left(1).to_upper()
		draw_string(font, Vector2(at.x - radius, at.y + font_size * 0.35), initial, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, ring)
	if unit.health.current < unit.health.maximum or selection.has(unit):
		var width := radius * 2.0
		var top := at + Vector2(-radius, -radius - maxf(zoom * 2.5, 3.0))
		var bar := maxf(zoom, 1.0)
		draw_rect(Rect2(top, Vector2(width, bar)), Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(top, Vector2(width * unit.health.get_fraction(), bar)), health_color if battle.is_on_player_side(unit) else foe_health_color)

# Ages each entry of `list` by `delta` and drops those older than `lasts`.
func _age(list: Array[Dictionary], lasts: float, delta: float) -> void:
	for index in range(list.size() - 1, -1, -1):
		list[index]["age"] = float(list[index]["age"]) + delta
		if float(list[index]["age"]) >= lasts:
			list.remove_at(index)

func _on_unit_attacked(attacker: RtsUnit, target: RtsUnit, _amount: int) -> void:
	_flashes.append({"from": attacker.position, "to": target.position, "age": 0.0})
