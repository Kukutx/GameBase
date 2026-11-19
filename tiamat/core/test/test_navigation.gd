extends GutTest

const RIVERSIDE_RECTS: Array[Rect2] = [
	Rect2(-372, -202, 340, 404),
	Rect2(-32, -24, 64, 48),
	Rect2(32, -202, 340, 404),
]

func test_simple_navigation_region_splits_partial_rect_connections_into_shared_cells() -> void:
	var region := SimpleNavigationRegion.new()
	region.walkable_rects = RIVERSIDE_RECTS
	add_child_autofree(region)
	await get_tree().process_frame

	assert_eq(region.get_polygon_count(), 7)
	assert_gt(region.navigation_polygon.vertices.size(), 8)

func test_riverside_navigation_geometry_connects_both_banks_only_at_bridge() -> void:
	var region := SimpleNavigationRegion.new()
	region.walkable_rects = RIVERSIDE_RECTS
	add_child_autofree(region)
	await get_tree().process_frame

	var bridge_polygon_found := false
	var left_shared_edge := false
	var right_shared_edge := false
	for polygon_index in range(region.navigation_polygon.get_polygon_count()):
		var points := _get_polygon_points(region.navigation_polygon, polygon_index)
		if points.is_empty():
			continue
		var min_x := INF
		var max_x := -INF
		var min_y := INF
		var max_y := -INF
		for point: Vector2 in points:
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
			min_y = minf(min_y, point.y)
			max_y = maxf(max_y, point.y)
		if is_equal_approx(min_x, -32.0) and is_equal_approx(max_x, 32.0) and is_equal_approx(min_y, -24.0) and is_equal_approx(max_y, 24.0):
			bridge_polygon_found = true
		if is_equal_approx(max_x, -32.0) and points.has(Vector2(-32, -24)) and points.has(Vector2(-32, 24)):
			left_shared_edge = true
		if is_equal_approx(min_x, 32.0) and points.has(Vector2(32, -24)) and points.has(Vector2(32, 24)):
			right_shared_edge = true

	assert_true(bridge_polygon_found)
	assert_true(left_shared_edge)
	assert_true(right_shared_edge)

func _get_polygon_points(polygon: NavigationPolygon, polygon_index: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var vertices := polygon.vertices
	for vertex_index: int in polygon.get_polygon(polygon_index):
		result.append(vertices[vertex_index])
	return result
