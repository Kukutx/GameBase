class_name BattleGrid
extends RefCounted

## The cells of a grid battle (`AtbBattle`): a rectangle of `size` cells, some
## of them blocked (water, walls), some open ones giving cover (woods, ruins),
## where a unit takes `cover_reduction` less damage, and some rough ground
## (shallows, mud: `set_rough()`), which takes `rough_cost` steps to enter. A
## unit walks a cell at a time up, down, left or right, so the distance between
## two cells is the number of such steps on even ground, and an action's range
## counts the same way, over blocked cells too. Every search tries the
## directions in one order, so the same grid always gives the same walks and
## paths.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var size: Vector2i
## The share of damage a unit in cover does not take.
var cover_reduction := 0.0
## The steps entering rough ground takes.
var rough_cost := 2
var _blocked: Dictionary[Vector2i, bool] = {}
var _cover: Dictionary[Vector2i, bool] = {}
var _rough: Dictionary[Vector2i, bool] = {}

func _init(grid_size := Vector2i(1, 1), blocked_cells: Array[Vector2i] = [], cover_cells: Array[Vector2i] = [], reduction := 0.0) -> void:
	size = Vector2i(maxi(grid_size.x, 1), maxi(grid_size.y, 1))
	for cell: Vector2i in blocked_cells:
		if has_cell(cell):
			_blocked[cell] = true
	for cell: Vector2i in cover_cells:
		if is_open(cell):
			_cover[cell] = true
	cover_reduction = clampf(reduction, 0.0, 1.0)

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

## Makes the open ones of `cells` rough ground, which takes `cost` steps to
## enter.
func set_rough(cells: Array[Vector2i], cost := 2) -> void:
	_rough.clear()
	for cell: Vector2i in cells:
		if is_open(cell):
			_rough[cell] = true
	rough_cost = maxi(cost, 1)

## Whether `cell` is rough ground.
func is_rough(cell: Vector2i) -> bool:
	return _rough.has(cell)

## The steps entering `cell` takes: `rough_cost` on rough ground, else 1.
func step_cost(cell: Vector2i) -> int:
	return rough_cost if _rough.has(cell) else 1

## Whether `cell` gives cover to who stands there.
func is_cover(cell: Vector2i) -> bool:
	return _cover.has(cell)

## `amount` of damage as a unit standing on `cell` takes it: `cover_reduction`
## less in cover, rounded, and never below 1.
func damage_on(cell: Vector2i, amount: int) -> int:
	if amount <= 0 or cover_reduction <= 0.0 or not _cover.has(cell):
		return amount
	return maxi(roundi(amount * (1.0 - cover_reduction)), 1)

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
## its foes); `from` itself at 0. Entering rough ground takes its
## `rough_cost` steps.
func walk(from: Vector2i, steps: int, walls: Dictionary[Vector2i, bool] = {}) -> Dictionary[Vector2i, int]:
	var reached: Dictionary[Vector2i, int] = {from: 0}
	# The cells to go on from, by the steps they took, each in the order it
	# was reached: on even ground a breadth-first search.
	var buckets: Array[Array] = [[from]]
	var cost := 0
	while cost < buckets.size():
		for cell: Vector2i in buckets[cost]:
			# Reached in fewer steps since.
			if reached[cell] != cost:
				continue
			for direction: Vector2i in DIRECTIONS:
				var next := cell + direction
				if not is_open(next) or walls.has(next):
					continue
				var next_cost := cost + step_cost(next)
				if next_cost > steps or (reached.has(next) and reached[next] <= next_cost):
					continue
				reached[next] = next_cost
				_queue(buckets, next_cost, next)
		cost += 1
	return reached

## The walk from `from` to `to` of the fewest steps through open cells not in
## `walls`, without `from` and ending at `to`, which may be a wall (the cell
## of the foe it walks up to); empty when there is none.
func path(from: Vector2i, to: Vector2i, walls: Dictionary[Vector2i, bool] = {}) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if from == to or not has_cell(to):
		return cells
	var came_from: Dictionary[Vector2i, Vector2i] = {from: from}
	var cost_to: Dictionary[Vector2i, int] = {from: 0}
	var buckets: Array[Array] = [[from]]
	var cost := 0
	while cost < buckets.size() and not (cost_to.has(to) and cost_to[to] < cost):
		for cell: Vector2i in buckets[cost]:
			if cost_to[cell] != cost or cell == to:
				continue
			for direction: Vector2i in DIRECTIONS:
				var next := cell + direction
				if not is_open(next) or (walls.has(next) and next != to):
					continue
				var next_cost := cost + step_cost(next)
				if cost_to.has(next) and cost_to[next] <= next_cost:
					continue
				cost_to[next] = next_cost
				came_from[next] = cell
				_queue(buckets, next_cost, next)
		cost += 1
	if not came_from.has(to):
		return cells
	var cell := to
	while cell != from:
		cells.push_front(cell)
		cell = came_from[cell]
	return cells

# Puts `cell` in the bucket of `cost`.
static func _queue(buckets: Array[Array], cost: int, cell: Vector2i) -> void:
	while buckets.size() <= cost:
		buckets.append([])
	buckets[cost].append(cell)
