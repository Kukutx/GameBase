extends GutTest

## The cells of a grid battle: distances and ranges in steps, walks that stop
## at blocked cells and foes, and the shortest paths around them.

func test_ranges_count_steps_over_any_cell_within_the_grid() -> void:
	var grid := BattleGrid.new(Vector2i(4, 3), [Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(BattleGrid.distance(Vector2i(0, 0), Vector2i(2, 1)), 3)
	assert_eq(grid.cells_in_range(Vector2i(0, 0), 1, 1), [Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i], "a blocked cell is in range: a shot flies over water")
	assert_eq(grid.cells_in_range(Vector2i(0, 0), 2, 2), [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2)] as Array[Vector2i])
	assert_eq(grid.cells_in_range(Vector2i(1, 1), 0, 0), [Vector2i(1, 1)] as Array[Vector2i])
	assert_false(grid.is_open(Vector2i(1, 0)))
	assert_false(grid.is_open(Vector2i(4, 0)), "outside the grid")
	assert_true(grid.is_open(Vector2i(3, 2)))

func test_a_walk_goes_around_blocked_cells_and_foes_within_its_steps() -> void:
	# . # . .
	# . # . .
	# . . F .
	var grid := BattleGrid.new(Vector2i(4, 3), [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i])
	var walls: Dictionary[Vector2i, bool] = {Vector2i(2, 2): true}
	var reached := grid.walk(Vector2i(0, 0), 4, walls)
	assert_eq(reached[Vector2i(0, 0)], 0)
	assert_eq(reached[Vector2i(1, 2)], 3)
	assert_false(reached.has(Vector2i(2, 2)), "a foe's cell is a wall")
	assert_false(reached.has(Vector2i(2, 1)), "the foe holds the only way round")
	assert_false(reached.has(Vector2i(1, 0)))
	assert_eq(grid.walk(Vector2i(0, 0), 0).keys(), [Vector2i(0, 0)])

func test_the_shortest_path_ends_at_its_goal_and_goes_up_to_a_foe() -> void:
	var grid := BattleGrid.new(Vector2i(4, 3), [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(grid.path(Vector2i(0, 0), Vector2i(2, 0)), [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0)] as Array[Vector2i])
	var walls: Dictionary[Vector2i, bool] = {Vector2i(2, 2): true}
	assert_eq(grid.path(Vector2i(0, 0), Vector2i(2, 2), walls).back(), Vector2i(2, 2), "the foe's own cell ends the path")
	assert_eq(grid.path(Vector2i(0, 0), Vector2i(3, 0), walls), [] as Array[Vector2i], "no way past the foe")
	assert_eq(grid.path(Vector2i(0, 0), Vector2i(0, 0)), [] as Array[Vector2i])
	assert_eq(grid.path(Vector2i(0, 0), Vector2i(9, 9)), [] as Array[Vector2i])
