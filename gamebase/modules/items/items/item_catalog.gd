class_name GameItemCatalog
extends Node

func has_item(item_id: StringName) -> bool:
	return ContentDB.has_item(item_id)

func get_item(item_id: StringName) -> ItemData:
	return ContentDB.get_item(item_id)

func get_items(item_ids: Array[StringName]) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item_id: StringName in item_ids:
		var item := get_item(item_id)
		if item != null:
			result.append(item)
	return result

func get_all_items() -> Array[ItemData]:
	return ContentDB.get_all_items()
