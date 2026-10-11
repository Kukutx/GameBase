class_name GlobalGameEvents
extends Node

signal toast_requested(message: String)
signal item_used(item_id: StringName)
signal item_foraged(item_id: StringName, quantity: int)
signal crop_harvested(crop_id: StringName, item_id: StringName, quantity: int)
signal npc_talked(npc_id: StringName)
signal gift_given(npc_id: StringName, item_id: StringName, friendship_delta: int)
signal animal_petted(animal_id: StringName, happiness: int)
signal animal_product_collected(animal_id: StringName, item_id: StringName, quantity: int)
signal fish_caught(fish_id: StringName, item_id: StringName)
signal resource_mined(node_id: StringName, item_id: StringName, quantity: int)
signal enemy_defeated(enemy_id: StringName, combat_xp: int)
signal item_processed(recipe_id: StringName, item_id: StringName, quantity: int)
signal tool_upgraded(upgrade_id: StringName, result_item_id: StringName)

func toast(message: String) -> void:
	if message.is_empty():
		return
	toast_requested.emit(tr(message))

func toastf(template: String, args: Array[Variant] = []) -> void:
	if template.is_empty():
		return
	var resolved: Array[Variant] = []
	for arg: Variant in args:
		if arg is String or arg is StringName:
			resolved.append(tr(String(arg)))
		else:
			resolved.append(arg)
	toast_requested.emit(tr(template) % resolved)
