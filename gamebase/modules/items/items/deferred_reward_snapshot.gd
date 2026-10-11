class_name DeferredRewardSnapshot
extends RefCounted

## A reward promised now and granted later (quests, mail, projects, milestones):
## `{"items": {item_id: quantity}, "money": int}`. Freezing it when it is promised
## keeps what the player receives stable while content changes before the claim.

static func capture(item_quantities: Dictionary, money: int = 0) -> Dictionary:
	var items: Dictionary = {}
	for raw_id: Variant in item_quantities.keys():
		var item_id := String(raw_id)
		var quantity := _safe_nonnegative_int(item_quantities[raw_id])
		if item_id.is_empty() or quantity <= 0:
			continue
		items[item_id] = quantity
	return {
		"items": items,
		"money": maxi(money, 0),
	}

## The stored snapshot when it is well formed, otherwise a new capture of
## `items` and `money`.
static func ensure(snapshot: Variant, items: Dictionary, money: int = 0) -> Dictionary:
	if snapshot is Dictionary:
		var existing: Dictionary = snapshot
		var raw_items: Variant = existing.get("items", {})
		if raw_items is Dictionary and existing.has("money"):
			return capture(raw_items as Dictionary, _safe_nonnegative_int(existing["money"]))
	return capture(items, money)

## Adds the snapshot's items to the inventory, all or none. Items that are no
## longer content are skipped.
static func grant_items(snapshot: Dictionary) -> bool:
	var raw_items: Variant = snapshot.get("items", {})
	if not raw_items is Dictionary:
		return false
	var items: Dictionary = {}
	for raw_id: Variant in (raw_items as Dictionary).keys():
		if ItemData.find(StringName(String(raw_id))) != null:
			items[raw_id] = _safe_nonnegative_int((raw_items as Dictionary)[raw_id])
	return InventoryState.add_items_atomic(items)

static func get_money(snapshot: Dictionary) -> int:
	return _safe_nonnegative_int(snapshot.get("money", 0))

static func _safe_nonnegative_int(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	return maxi(int(value), 0)
