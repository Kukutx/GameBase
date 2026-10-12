class_name GridBattleBoard
extends Control

## The grid of a grid battle as the player sees it (`GridBattleGame`): the
## cells, scaled to fit the board's size, the cells a command may pick, the
## cursor, the units with their health and gauges, the numbers of what an
## action took or gave back, and the unit whose turn it is. Units walk the
## path they took, unless the player asked for reduced motion. It reports the
## cell under the mouse and the cell clicked.

signal cell_hovered(cell: Vector2i)
signal cell_clicked(cell: Vector2i)

## How long a number of an action's hit shows.
const FLOAT_SECONDS := 0.9
## How many cells a second a unit walks on the board.
const WALK_CELLS_PER_SECOND := 8.0

@export var ground_color := Color(0.33, 0.43, 0.29)
@export var ground_alt_color := Color(0.3, 0.4, 0.27)
@export var blocked_color := Color(0.17, 0.23, 0.31)
@export var choice_color := Color(0.45, 0.7, 1.0, 0.45)
@export var reach_color := Color(1.0, 0.45, 0.35, 0.22)
@export var area_color := Color(1.0, 0.65, 0.25, 0.5)
@export var cursor_color := Color(1.0, 1.0, 1.0, 0.95)
@export var turn_color := Color(1.0, 0.86, 0.35)
@export var player_side_color := Color(0.95, 0.92, 0.78)
@export var foe_side_color := Color(0.6, 0.14, 0.14)
@export var health_color := Color(0.4, 0.85, 0.45)
@export var gauge_color := Color(0.98, 0.82, 0.3)
@export var damage_color := Color(1.0, 0.45, 0.4)
@export var heal_color := Color(0.5, 1.0, 0.6)

var battle: AtbBattle
var cursor := Vector2i.ZERO
var show_cursor := false
## The cells a command may pick now, drawn in `choice_color`.
var choices: Array[Vector2i] = []
## The cells an action reaches from its user, in `reach_color`.
var reach: Array[Vector2i] = []
## The cells the action aimed at the cursor would reach, in `area_color`.
var area: Array[Vector2i] = []
## The unit whose turn it is, outlined.
var turn_unit: GridUnit

# Where each unit shows, in cells, and the cells it still walks through.
var _shown: Dictionary[GridUnit, Vector2] = {}
var _routes: Dictionary[GridUnit, Array] = {}
var _floats: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## Shows `battle_to_show` and follows what happens in it.
func show_battle(battle_to_show: AtbBattle) -> void:
	battle = battle_to_show
	_shown.clear()
	_routes.clear()
	for unit: GridUnit in battle.units:
		_shown[unit] = Vector2(unit.cell)
	battle.unit_moved.connect(_on_unit_moved)
	battle.unit_acted.connect(_on_unit_acted)
	queue_redraw()

## The side of a cell, in pixels, that fits the grid in the board.
func get_cell_size() -> float:
	if battle == null:
		return 1.0
	return maxf(floorf(minf(size.x / battle.grid.size.x, size.y / battle.grid.size.y)), 1.0)

## Where the grid's top left corner is on the board.
func get_origin() -> Vector2:
	return ((size - Vector2(battle.grid.size) * get_cell_size()) * 0.5).floor()

## The cell at `point` on the board, which may lie outside the grid.
func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(((point - get_origin()) / get_cell_size()).floor())

## Whether the units have walked where they went and the numbers have faded.
func is_settled() -> bool:
	return _routes.is_empty() and _floats.is_empty()

func _process(delta: float) -> void:
	if battle == null:
		return
	var steps := WALK_CELLS_PER_SECOND * delta
	for unit: GridUnit in battle.units:
		var route: Array = _routes.get(unit, [])
		if GameSettings.reduced_motion:
			route.clear()
		var goal := Vector2(route[0] if not route.is_empty() else unit.cell)
		var at: Vector2 = _shown.get(unit, goal)
		at = goal if GameSettings.reduced_motion else at.move_toward(goal, steps)
		_shown[unit] = at
		if not route.is_empty() and at == goal:
			route.pop_front()
		if route.is_empty():
			_routes.erase(unit)
	for index in range(_floats.size() - 1, -1, -1):
		_floats[index]["age"] = float(_floats[index]["age"]) + delta
		if float(_floats[index]["age"]) >= FLOAT_SECONDS:
			_floats.remove_at(index)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if battle == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var hovered := cell_at(motion.position)
		if battle.grid.has_cell(hovered):
			cell_hovered.emit(hovered)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var clicked := cell_at(click.position)
		if battle.grid.has_cell(clicked):
			accept_event()
			cell_clicked.emit(clicked)

func _draw() -> void:
	if battle == null:
		return
	var side := get_cell_size()
	var origin := get_origin()
	for y in battle.grid.size.y:
		for x in battle.grid.size.x:
			var cell := Vector2i(x, y)
			var color := blocked_color if battle.grid.is_blocked(cell) else (ground_color if (x + y) % 2 == 0 else ground_alt_color)
			draw_rect(_cell_rect(cell, origin, side), color)
	for cell: Vector2i in reach:
		draw_rect(_cell_rect(cell, origin, side), reach_color)
	for cell: Vector2i in choices:
		draw_rect(_cell_rect(cell, origin, side), choice_color)
	for cell: Vector2i in area:
		draw_rect(_cell_rect(cell, origin, side), area_color)
	for unit: GridUnit in battle.units:
		if unit.is_alive():
			_draw_unit(unit, origin, side)
	if turn_unit != null and turn_unit.is_alive():
		draw_rect(Rect2(origin + _shown.get(turn_unit, Vector2(turn_unit.cell)) * side, Vector2(side, side)).grow(-0.5), turn_color, false, 1.0)
	if show_cursor:
		draw_rect(_cell_rect(cursor, origin, side).grow(-0.5), cursor_color, false, 1.0)
	var font := get_theme_default_font()
	var font_size := maxi(roundi(side * 0.45), 8)
	for entry: Dictionary in _floats:
		var age: float = entry["age"]
		var rise := 0.0 if GameSettings.reduced_motion else age / FLOAT_SECONDS * 0.6
		var at := origin + (Vector2(entry["cell"] as Vector2i) + Vector2(0.0, 0.25 - rise)) * side
		var color: Color = entry["color"]
		color.a = 1.0 - age / FLOAT_SECONDS * 0.6
		draw_string(font, at, String(entry["text"]), HORIZONTAL_ALIGNMENT_CENTER, side, font_size, color)

func _draw_unit(unit: GridUnit, origin: Vector2, side: float) -> void:
	var rect := Rect2(origin + _shown.get(unit, Vector2(unit.cell)) * side, Vector2(side, side))
	var center := rect.get_center() - Vector2(0.0, side * 0.08)
	var ring := player_side_color if battle.is_on_player_side(unit) else foe_side_color
	if unit.data.texture != null:
		draw_texture_rect(unit.data.texture, rect.grow(-1.0), false)
	else:
		var radius := side * 0.34
		draw_circle(center, radius, unit.data.color)
		draw_arc(center, radius, 0.0, TAU, 20, ring, maxf(side * 0.06, 1.0))
		var font := get_theme_default_font()
		var font_size := maxi(roundi(side * 0.4), 8)
		var initial := TranslationServer.translate(unit.data.display_name).left(1).to_upper()
		draw_string(font, Vector2(rect.position.x, center.y + font_size * 0.35), initial, HORIZONTAL_ALIGNMENT_CENTER, side, font_size, ring)
	var bar := maxf(side * 0.08, 1.0)
	var width := side - 4.0
	var bottom := rect.end.y - 1.0
	draw_rect(Rect2(rect.position.x + 2.0, bottom - bar * 2.0 - 1.0, width, bar * 2.0 + 1.0), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(rect.position.x + 2.0, bottom - bar * 2.0 - 1.0, width * unit.health.get_fraction(), bar), health_color if battle.is_on_player_side(unit) else damage_color)
	draw_rect(Rect2(rect.position.x + 2.0, bottom - bar, width * unit.get_gauge_fraction(), bar), gauge_color)

func _cell_rect(cell: Vector2i, origin: Vector2, side: float) -> Rect2:
	return Rect2(origin + Vector2(cell) * side, Vector2(side, side))

func _on_unit_moved(unit: GridUnit, path: Array[Vector2i]) -> void:
	_routes[unit] = path.duplicate()

func _on_unit_acted(_unit: GridUnit, action: BattleActionData, _cell: Vector2i, hits: Array[Dictionary]) -> void:
	var heals := action.effect == BattleActionData.Effect.HEAL
	for hit: Dictionary in hits:
		var target: GridUnit = hit["unit"]
		_floats.append({
			"cell": target.cell,
			"text": ("+%d" if heals else "-%d") % int(hit["amount"]),
			"color": heal_color if heals else damage_color,
			"age": 0.0,
		})
