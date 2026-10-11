class_name TownProjectData
extends Resource

@export var id: StringName
@export var display_name: String = "Town Project"
@export_multiline var description: String
@export var location_id: StringName
@export var prerequisites: Array[StringName] = []
@export var requirements: Dictionary = {}
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}
@export var unlock_flags: Array[StringName] = []

func get_required_quantity(item_id: StringName) -> int:
	var raw: Variant = requirements.get(String(item_id), 0)
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return 0
	return maxi(int(raw), 0)

func has_requirement(item_id: StringName) -> bool:
	return get_required_quantity(item_id) > 0
