class_name FarmField
extends Node2D

@export var field_id: StringName
@export var location_id: StringName
@export_range(1, 64, 1) var columns := 3
@export_range(1, 64, 1) var rows := 1
@export var cell_spacing := Vector2(45, 32)
@export var plot_scene: PackedScene = preload("res://gamebase/modules/lifesim/farming/farm_plot.tscn")

var _plots: Dictionary = {}

func _ready() -> void:
	generate()

func generate() -> void:
	if not _plots.is_empty():
		return
	if field_id == &"":
		push_warning("FarmField requires a stable field_id for persistence")
	var resolved_location := location_id
	if resolved_location == &"":
		var location := ContentDB.get_current_location(get_tree())
		if location != null:
			resolved_location = location.id
	var center_offset := Vector2((columns - 1) * cell_spacing.x, (rows - 1) * cell_spacing.y) * 0.5
	var flat_index := 0
	for y in rows:
		for x in columns:
			var plot := plot_scene.instantiate() as FarmPlot
			if plot == null:
				continue
			flat_index += 1
			plot.name = "Plot_%02d_%02d" % [x + 1, y + 1]
			plot.position = Vector2(x * cell_spacing.x, y * cell_spacing.y) - center_offset
			plot.location_id = resolved_location
			if field_id != &"":
				plot.persistent_id = StringName("%s_%02d" % [String(field_id), flat_index])
			add_child(plot)
			_plots[Vector2i(x, y)] = plot

func get_plot(cell: Vector2i) -> FarmPlot:
	return _plots.get(cell) as FarmPlot

func get_all_plots() -> Array[FarmPlot]:
	var result: Array[FarmPlot] = []
	for value: Variant in _plots.values():
		result.append(value as FarmPlot)
	return result

func get_plot_count() -> int:
	return _plots.size()

## The world state of the plots the field generates, for `ContentRegistry`'s
## check that no two nodes share it.
func get_persistent_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	if field_id != &"":
		for index: int in range(1, columns * rows + 1):
			keys.append("farm:%s_%02d" % [String(field_id), index])
	return keys

func find_scene_problems(_registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	if field_id == &"":
		problems.append("farm field '%s' has no field id" % name)
	if location != null and location_id != &"" and location_id != location.id:
		problems.append("farm field '%s' references different location '%s'" % [name, location_id])
	return problems
