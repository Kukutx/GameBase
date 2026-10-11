class_name FarmExpansionData
extends Resource

@export var id: StringName
@export var display_name: String = "Farm Expansion"
@export_multiline var description: String
@export var housing_id: StringName
@export_range(1, 32, 1) var capacity_after := 8
@export_range(0, 999999, 1) var money_cost := 0
@export var materials: Dictionary = {}
@export var prerequisites: Array[StringName] = []
@export var required_world_flag: StringName

func has_valid_cost() -> bool:
	return money_cost > 0 or not materials.is_empty()
