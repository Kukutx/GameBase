class_name SimpleNavigationRegion
extends NavigationRegion2D

@export var walkable_rects: Array[Rect2] = []

func _ready() -> void:
	rebuild_navigation()

## Builds the navigation polygon from `walkable_rects`: the rects' edges cut
## the area into a grid, and each cell a rect covers becomes a polygon. Each
## rect marks only its own cells, so the work grows with the area the rects
## cover, not with the cube of their number.
func rebuild_navigation() -> void:
	var x_values: Array[float] = []
	var y_values: Array[float] = []
	for rect: Rect2 in walkable_rects:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		x_values.append_array([rect.position.x, rect.end.x])
		y_values.append_array([rect.position.y, rect.end.y])
	var x_edges := _distinct_sorted(x_values)
	var y_edges := _distinct_sorted(y_values)
	var columns := maxi(x_edges.size() - 1, 0)
	var rows := maxi(y_edges.size() - 1, 0)

	var covered := PackedByteArray()
	covered.resize(columns * rows)
	for rect: Rect2 in walkable_rects:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var left := _edge_index(x_edges, rect.position.x)
		var right := _edge_index(x_edges, rect.end.x)
		var top := _edge_index(y_edges, rect.position.y)
		var bottom := _edge_index(y_edges, rect.end.y)
		for column in range(left, right):
			for row in range(top, bottom):
				covered[column * rows + row] = 1

	var nav := NavigationPolygon.new()
	var vertices := PackedVector2Array()
	var vertex_indices: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	for column in range(columns):
		for row in range(rows):
			if covered[column * rows + row] == 0:
				continue
			var left := x_edges[column]
			var right := x_edges[column + 1]
			var top := y_edges[row]
			var bottom := y_edges[row + 1]
			if right - left <= 0.001 or bottom - top <= 0.001:
				continue
			var polygon := PackedInt32Array()
			for corner: Vector2 in [Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]:
				polygon.append(_get_vertex_index(corner, vertices, vertex_indices))
			polygons.append(polygon)

	nav.vertices = vertices
	for polygon: PackedInt32Array in polygons:
		nav.add_polygon(polygon)
	navigation_polygon = nav

func get_polygon_count() -> int:
	return navigation_polygon.get_polygon_count() if navigation_polygon != null else 0

# `values` sorted, without values approximately equal to the one before.
static func _distinct_sorted(values: Array[float]) -> Array[float]:
	values.sort()
	var result: Array[float] = []
	for value: float in values:
		if result.is_empty() or not is_equal_approx(result[-1], value):
			result.append(value)
	return result

# The index of the edge approximately equal to `value`.
static func _edge_index(edges: Array[float], value: float) -> int:
	var index := edges.bsearch(value)
	if index > 0 and (index >= edges.size() or absf(edges[index - 1] - value) <= absf(edges[index] - value)):
		return index - 1
	return index

static func _get_vertex_index(point: Vector2, vertices: PackedVector2Array, index_by_point: Dictionary) -> int:
	if index_by_point.has(point):
		return int(index_by_point[point])
	var index := vertices.size()
	vertices.append(point)
	index_by_point[point] = index
	return index
