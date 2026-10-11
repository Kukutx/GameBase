class_name SimpleNavigationRegion
extends NavigationRegion2D

@export var walkable_rects: Array[Rect2] = []

func _ready() -> void:
	rebuild_navigation()

func rebuild_navigation() -> void:
	var nav := NavigationPolygon.new()
	var vertices := PackedVector2Array()
	var polygons: Array[PackedInt32Array] = []
	var vertex_indices: Dictionary = {}
	var x_edges: Array[float] = []
	var y_edges: Array[float] = []

	for rect: Rect2 in walkable_rects:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		_append_unique_float(x_edges, rect.position.x)
		_append_unique_float(x_edges, rect.end.x)
		_append_unique_float(y_edges, rect.position.y)
		_append_unique_float(y_edges, rect.end.y)
	x_edges.sort()
	y_edges.sort()

	for x_index in range(maxi(x_edges.size() - 1, 0)):
		for y_index in range(maxi(y_edges.size() - 1, 0)):
			var left := x_edges[x_index]
			var right := x_edges[x_index + 1]
			var top := y_edges[y_index]
			var bottom := y_edges[y_index + 1]
			if right - left <= 0.001 or bottom - top <= 0.001:
				continue
			var center := Vector2((left + right) * 0.5, (top + bottom) * 0.5)
			if not _is_walkable(center):
				continue
			var corners := PackedVector2Array([
				Vector2(left, top),
				Vector2(right, top),
				Vector2(right, bottom),
				Vector2(left, bottom),
			])
			var polygon := PackedInt32Array()
			for corner: Vector2 in corners:
				polygon.append(_get_vertex_index(corner, vertices, vertex_indices))
			polygons.append(polygon)

	nav.vertices = vertices
	for polygon: PackedInt32Array in polygons:
		nav.add_polygon(polygon)
	navigation_polygon = nav

func get_polygon_count() -> int:
	return navigation_polygon.get_polygon_count() if navigation_polygon != null else 0

func _is_walkable(point: Vector2) -> bool:
	for rect: Rect2 in walkable_rects:
		if rect.has_point(point):
			return true
	return false

func _append_unique_float(values: Array[float], value: float) -> void:
	for existing: float in values:
		if is_equal_approx(existing, value):
			return
	values.append(value)

func _get_vertex_index(point: Vector2, vertices: PackedVector2Array, index_by_key: Dictionary) -> int:
	var key := "%0.4f:%0.4f" % [point.x, point.y]
	if index_by_key.has(key):
		return int(index_by_key[key])
	var index := vertices.size()
	vertices.append(point)
	index_by_key[key] = index
	return index
