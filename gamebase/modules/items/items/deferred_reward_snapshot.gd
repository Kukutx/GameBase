class_name DeferredRewardSnapshot
extends RefCounted

static func capture(item_quantities: Dictionary, money: int = 0) -> Dictionary:
	var items: Dictionary = {}
	for raw_id: Variant in item_quantities.keys():
		var item_id := StringName(String(raw_id))
		var quantity := _safe_nonnegative_int(item_quantities[raw_id])
		if item_id == &"" or quantity <= 0:
			continue
		var item := ContentDB.get_item(item_id)
		items[String(item_id)] = {
			"quantity": quantity,
			"display_name": item.display_name if item != null else String(item_id),
			"max_stack": item.max_stack if item != null else 99,
		}
	return {
		"items": items,
		"money": maxi(money, 0),
	}

static func ensure(snapshot: Variant, fallback_items: Dictionary, fallback_money: int = 0) -> Dictionary:
	if snapshot is Dictionary:
		var existing: Dictionary = snapshot
		var raw_items: Variant = existing.get("items", {})
		if raw_items is Dictionary and existing.has("money"):
			return {
				"items": (raw_items as Dictionary).duplicate(true),
				"money": _safe_nonnegative_int(existing.get("money", 0)),
			}
	return capture(fallback_items, fallback_money)

static func grant_items(snapshot: Dictionary) -> bool:
	var raw_items: Variant = snapshot.get("items", {})
	if not raw_items is Dictionary:
		return false
	return InventoryState.apply_refund_snapshot_atomic(raw_items as Dictionary)

static func get_money(snapshot: Dictionary) -> int:
	return _safe_nonnegative_int(snapshot.get("money", 0))

static func _safe_nonnegative_int(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	return maxi(int(value), 0)
