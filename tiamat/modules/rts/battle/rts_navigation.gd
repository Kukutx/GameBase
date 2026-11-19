class_name RtsNavigation
extends RefCounted

## Where units walk on the field of a command battle (`RtsBattle`): the field
## cut in square cells of `CELL_SIZE` pixels, the cells an obstacle touches
## (grown by `CLEARANCE`) or whose middle lies off the field closed, and the
## way between two points through open cells: the straight line when nothing
## is in it, else the shortest way from cell to cell with the corners it can
## cut cut. A point is open when it lies on the field in an open cell.

## The side of a cell, in pixels.
const CELL_SIZE := 8.0
## How far from an obstacle a unit's middle keeps.
const CLEARANCE := 4.0

var size: Vector2
## The rectangles no unit walks through.
var obstacles: Array[Rect2] = []
var _grid := AStarGrid2D.new()

func _init(field_size: Vector2, field_obstacles: Array[Rect2] = []) -> void:
	size = field_size
	for obstacle: Rect2 in field_obstacles:
		obstacles.append(obstacle.abs())
	_grid.region = Rect2i(Vector2i.ZERO, Vector2i((field_size / CELL_SIZE).ceil()))
	_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_grid.offset = Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	var region := _grid.region
	for y in region.size.y:
		for x in region.size.x:
			var middle := get_cell_middle(Vector2i(x, y))
			if middle.x >= size.x or middle.y >= size.y:
				_grid.set_point_solid(Vector2i(x, y))
	for obstacle: Rect2 in obstacles:
		var grown := obstacle.grow(CLEARANCE)
		var first := Vector2i((grown.position / CELL_SIZE).floor()).max(Vector2i.ZERO)
		var last := (Vector2i((grown.end / CELL_SIZE).ceil()) - Vector2i.ONE).min(region.end - Vector2i.ONE)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				_grid.set_point_solid(Vector2i(x, y))

## The cell `point` lies in, which may be off the field.
static func get_cell(point: Vector2) -> Vector2i:
	return Vector2i((point / CELL_SIZE).floor())

## The middle of `cell`, in pixels.
static func get_cell_middle(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE

## Whether a unit may stand at `point`.
func is_open(point: Vector2) -> bool:
	if point.x < 0.0 or point.y < 0.0 or point.x >= size.x or point.y >= size.y:
		return false
	return not _is_closed(get_cell(point))

## Whether a unit walks the straight line from `from` to `to` through open
## cells only: through each cell it crosses, and through both cells beside a
## corner it passes exactly.
func is_line_open(from: Vector2, to: Vector2) -> bool:
	if not is_open(from) or not is_open(to):
		return false
	var cell := get_cell(from)
	var last := get_cell(to)
	var direction := to - from
	var step := Vector2i(int(signf(direction.x)), int(signf(direction.y)))
	# How far along the line, as a share of it, the next edge across each axis
	# lies, and how far apart those edges lie.
	var next := Vector2(INF, INF)
	var apart := Vector2(INF, INF)
	if step.x != 0:
		next.x = ((cell.x + maxi(step.x, 0)) * CELL_SIZE - from.x) / direction.x
		apart.x = CELL_SIZE / absf(direction.x)
	if step.y != 0:
		next.y = ((cell.y + maxi(step.y, 0)) * CELL_SIZE - from.y) / direction.y
		apart.y = CELL_SIZE / absf(direction.y)
	var crossings := absi(last.x - cell.x) + absi(last.y - cell.y)
	while cell != last and crossings > 0:
		if is_equal_approx(next.x, next.y):
			if _is_closed(cell + Vector2i(step.x, 0)) or _is_closed(cell + Vector2i(0, step.y)):
				return false
			cell += step
			next += apart
			crossings -= 2
		elif next.x < next.y:
			cell.x += step.x
			next.x += apart.x
			crossings -= 1
		else:
			cell.y += step.y
			next.y += apart.y
			crossings -= 1
		if _is_closed(cell):
			return false
	return true

## An open point near `point`: the point itself when it is open, else the
## middle of the nearest open cell around it, or `point` when the field has
## none.
func get_nearest_open(point: Vector2) -> Vector2:
	if is_open(point):
		return point
	var center := get_cell(point).clamp(Vector2i.ZERO, _grid.region.end - Vector2i.ONE)
	var widest := maxi(_grid.region.size.x, _grid.region.size.y)
	for ring in range(0, widest + 1):
		var best := Vector2.INF
		for cell: Vector2i in _ring(center, ring):
			var middle := get_cell_middle(cell)
			if is_open(middle) and middle.distance_squared_to(point) < best.distance_squared_to(point):
				best = middle
		if best != Vector2.INF:
			return best
	return point

## The points a unit at `from` walks through, in order, to get to `to`, or as
## near to it as it can get; `to` (or the open point nearest it) last.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var goal := get_nearest_open(to)
	if is_line_open(from, goal):
		return PackedVector2Array([goal])
	var start := get_nearest_open(from)
	var points := _grid.get_point_path(get_cell(start), get_cell(goal), true)
	if points.is_empty():
		return points
	if get_cell(points[points.size() - 1]) == get_cell(goal):
		points[points.size() - 1] = goal
	# Skips each point it can walk past in a straight line.
	var path := PackedVector2Array()
	var at := from
	var index := 0
	while index < points.size():
		var furthest := index
		while furthest + 1 < points.size() and is_line_open(at, points[furthest + 1]):
			furthest += 1
		path.append(points[furthest])
		at = points[furthest]
		index = furthest + 1
	return path

func _is_closed(cell: Vector2i) -> bool:
	return not _grid.is_in_boundsv(cell) or _grid.is_point_solid(cell)

# The cells `ring` cells from `center`, around it.
func _ring(center: Vector2i, ring: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if ring == 0:
		cells.append(center)
		return cells
	for x in range(-ring, ring + 1):
		cells.append(center + Vector2i(x, -ring))
		cells.append(center + Vector2i(x, ring))
	for y in range(-ring + 1, ring):
		cells.append(center + Vector2i(-ring, y))
		cells.append(center + Vector2i(ring, y))
	return cells
