class_name ToolUpgradeService
extends Node

signal tool_upgraded(upgrade_id: StringName, source_item_id: StringName, result_item_id: StringName)

var _upgrade_busy := false

func get_upgrade(upgrade_id: StringName) -> ToolUpgradeData:
	return ContentDB.get_tool_upgrade(upgrade_id)

func get_all_upgrades() -> Array[ToolUpgradeData]:
	return ContentDB.get_all_tool_upgrades()

func can_upgrade(upgrade: ToolUpgradeData) -> bool:
	if upgrade == null or not upgrade.meets_requirements():
		return false
	var source := ContentDB.get_item(upgrade.source_item_id)
	var result := ContentDB.get_item(upgrade.result_item_id)
	return source != null and source.is_tool() and result != null and result.is_tool()

func upgrade(upgrade_id: StringName) -> bool:
	if _upgrade_busy:
		return false
	_upgrade_busy = true
	var result := _upgrade_internal(upgrade_id)
	_upgrade_busy = false
	return result

func _upgrade_internal(upgrade_id: StringName) -> bool:
	var upgrade_data := get_upgrade(upgrade_id)
	if not can_upgrade(upgrade_data):
		GameEvents.toast("Missing tool, materials, money, or requirements")
		return false
	var source := ContentDB.get_item(upgrade_data.source_item_id)
	var result := ContentDB.get_item(upgrade_data.result_item_id)
	if source == null or result == null:
		return false

	var removals := upgrade_data.materials.duplicate(true)
	var source_key := String(source.id)
	removals[source_key] = int(removals.get(source_key, 0)) + 1
	if upgrade_data.money_cost > 0 and not PlayerState.spend_money(upgrade_data.money_cost):
		return false
	if not InventoryState.apply_transaction_atomic(removals, {String(result.id): 1}):
		if upgrade_data.money_cost > 0:
			PlayerState.add_money(upgrade_data.money_cost)
		GameEvents.toast("Inventory or materials changed before the upgrade completed")
		return false

	for index in range(Hotbar.slots.size()):
		if Hotbar.slots[index] == source.id:
			Hotbar.set_slot_item(index, result.id)
	tool_upgraded.emit(upgrade_data.id, source.id, result.id)
	GameEvents.tool_upgraded.emit(upgrade_data.id, result.id)
	GameEvents.toastf("Upgraded to %s", [result.display_name])
	return true

func get_requirement_text(upgrade: ToolUpgradeData) -> String:
	if upgrade == null:
		return ""
	var parts: PackedStringArray = []
	var material_ids: Array[String] = []
	for raw_id: Variant in upgrade.materials.keys():
		material_ids.append(String(raw_id))
	material_ids.sort()
	for raw_id: String in material_ids:
		var item := ContentDB.get_item(StringName(raw_id))
		var name_text := tr(item.display_name) if item != null else raw_id
		parts.append("%s x%d" % [name_text, int(upgrade.materials[raw_id])])
	if upgrade.money_cost > 0:
		parts.append("%dg" % upgrade.money_cost)
	parts.append_array(GameRules.describe(upgrade.condition))
	return " · ".join(parts)
