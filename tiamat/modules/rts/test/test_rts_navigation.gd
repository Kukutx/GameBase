extends GutTest

## Where units walk on the field of a command battle (`RtsNavigation`): the
## cells an obstacle or the edge closes, the straight line when it is clear,
## the way around an obstacle through open cells only, as near as it gets when
## nothing gets there, and the open point nearest a closed one.

func test_an_obstacle_and_the_edge_close_cells() -> void:
	var navigation := _navigation()
	assert_true(navigation.is_open(Vector2(10.0, 10.0)))
	assert_false(navigation.is_open(Vector2(44.0, 10.0)), "in the wall")
	assert_false(navigation.is_open(Vector2(37.0, 10.0)), "too near it")
	assert_true(navigation.is_open(Vector2(44.0, 50.0)), "past its end")
	assert_false(navigation.is_open(Vector2(-1.0, 10.0)))
	assert_false(navigation.is_open(Vector2(100.0, 10.0)))
	assert_false(navigation.is_open(Vector2(98.0, 10.0)), "in a cell whose middle lies off the field")

func test_a_clear_line_is_the_way_else_it_goes_around_through_open_cells() -> void:
	var navigation := _navigation()
	assert_eq(navigation.find_path(Vector2(10.0, 50.0), Vector2(90.0, 50.0)), PackedVector2Array([Vector2(90.0, 50.0)]))
	assert_false(navigation.is_line_open(Vector2(10.0, 10.0), Vector2(90.0, 10.0)))
	var around := navigation.find_path(Vector2(10.0, 10.0), Vector2(90.0, 10.0))
	assert_gt(around.size(), 1)
	assert_eq(around[around.size() - 1], Vector2(90.0, 10.0))
	var at := Vector2(10.0, 10.0)
	var lowest := 0.0
	for point: Vector2 in around:
		assert_true(navigation.is_line_open(at, point), "each leg of the way is open")
		lowest = maxf(lowest, point.y)
		at = point
	assert_gte(lowest, 48.0, "below the wall's end")

func test_with_no_way_there_it_goes_as_near_as_it_gets() -> void:
	var navigation := RtsNavigation.new(Vector2(100.0, 60.0), [Rect2(40.0, 0.0, 8.0, 60.0)] as Array[Rect2])
	var path := navigation.find_path(Vector2(10.0, 10.0), Vector2(90.0, 10.0))
	assert_false(path.is_empty())
	assert_lt(path[path.size() - 1].x, 32.0, "it stops on its side of the wall")

func test_the_nearest_open_point_of_a_closed_one() -> void:
	var navigation := _navigation()
	assert_eq(navigation.get_nearest_open(Vector2(10.0, 10.0)), Vector2(10.0, 10.0))
	var near := navigation.get_nearest_open(Vector2(44.0, 10.0))
	assert_true(navigation.is_open(near))
	assert_lt(near.distance_to(Vector2(44.0, 10.0)), 20.0)
	assert_true(navigation.is_open(navigation.get_nearest_open(Vector2(500.0, -30.0))), "off the field too")

# A field 100 by 60 with a wall from the top, 8 wide, 40 down.
func _navigation() -> RtsNavigation:
	return RtsNavigation.new(Vector2(100.0, 60.0), [Rect2(40.0, 0.0, 8.0, 40.0)] as Array[Rect2])
