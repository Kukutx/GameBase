class_name FoodBuffData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(1, 1440, 1) var duration_minutes := 180
@export var modifiers: Dictionary = {}

func get_multiplier(stat: StringName) -> float:
	return maxf(float(modifiers.get(String(stat), 1.0)), 0.01)
