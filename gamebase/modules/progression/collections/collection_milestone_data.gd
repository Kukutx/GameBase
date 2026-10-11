class_name CollectionMilestoneData
extends ContentEntry

@export var display_name: String
@export_multiline var description: String
@export var category: StringName
@export_range(0, 999, 1) var required_discovered := 0
@export var prerequisites: Array[StringName] = []
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}
@export var unlock_flags: Array[StringName] = []

func get_required_count() -> int:
	if category == &"":
		return prerequisites.size()
	if required_discovered > 0:
		return required_discovered
	return CollectionState.get_total_ids(category).size()
