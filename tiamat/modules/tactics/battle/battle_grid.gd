class_name BattleGrid
extends RefCounted

## The cells of a grid battle (`AtbBattle`): a rectangle of `size` cells, some
## of them blocked (water, walls). A unit walks a cell at a time up, down, left
## or right, so the distance between two cells is the number of such steps,
## and an action's range counts the same way, over blocked cells too. Every
## search tries the directions in one order, so the same grid always gives the
## same walks and paths.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var size: Vector2i
var _blocked: Dictionary[Vector2i, bool] = {}

func _init(grid_size := Vector2i(1, 1), blocked_cells: Array[Vector2i] = []) -> void:
	size = Vector2i(maxi(grid_size.x, 1), maxi(grid_size.y, 1))
	for cell: Vector2i in blocked_cells:
		if has_cell(cell):
			_blocked[cell] = true

## The steps between `from` and `to`.
static func distance(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)

func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)

## Whether a unit may stand on or walk through `cell`.
func is_open(cell: Vector2i) -> bool:
	return has_cell(cell) and not _blocked.has(cell)

## The cells of the grid from `min_range` to `max_range` steps from `center`,
## row by row.
func cells_in_range(center: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(center.y - max_range, center.y + max_range + 1):
		for x in range(center.x - max_range, center.x + max_range + 1):
			var cell := Vector2i(x, y)
			var steps := distance(center, cell)
			if steps >= min_range and steps <= max_range and has_cell(cell):
				cells.append(cell)
	return cells

## The steps to each cell a walker from `from` reaches in at most `steps`
## steps through open cells, but not through those in `walls` (cells holding
## its foes); `from` itself at 0.
func walk(from: Vector2i, steps: int, walls: Dictionary[Vector2i, bool] = {}) -> Dictionary[Vector2i, int]:
	var reached: Dictionary[Vector2i, int] = {from: 0}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		var next_steps := reached[cell] + 1
		if next_steps > steps:
			continue
		for direction: Vector2i in DIRECTIONS:
			var next := cell + direction
			if not reached.has(next) and is_open(next) and not walls.has(next):
				reached[next] = next_steps
				frontier.append(next)
	return reached

## The shortest walk from `from` to `to` through open cells not in `walls`,
## without `from` and ending at `to`, which may be a wall (the cell of the foe
## it walks up to); empty when there is none.
func path(from: Vector2i, to: Vector2i, walls: Dictionary[Vector2i, bool] = {}) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if from == to or not has_cell(to):
		return cells
	var came_from: Dictionary[Vector2i, Vector2i] = {from: from}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty() and not came_from.has(to):
		var cell: Vector2i = frontier.pop_front()
		for direction: Vector2i in DIRECTIONS:
			var next := cell + direction
			if came_from.has(next) or not is_open(next) or (walls.has(next) and next != to):
				continue
			came_from[next] = cell
			frontier.append(next)
	if not came_from.has(to):
		return cells
	var cell := to
	while cell != from:
		cells.push_front(cell)
		cell = came_from[cell]
	return cells
