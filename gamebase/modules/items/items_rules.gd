class_name ItemsRules
extends RefCounted

## Condition and action keys of the items module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"HAS_ITEM", _has_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_INT])
	rules.register_action(&"ADD_ITEM", _add_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_INT])
	rules.register_action(&"REMOVE_ITEM", _remove_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_INT])

## HAS_ITEM <item> [count]: the inventory holds at least count (default 1).
static func _has_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.has_item(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)

## ADD_ITEM <item> [count]: fails when the inventory could not take every item.
static func _add_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.add_item_by_id(StringName(args[0]), int(args[1]) if args.size() > 1 else 1) == 0

## REMOVE_ITEM <item> [count]: fails, removing nothing, when there are not enough.
static func _remove_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.remove_item(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)
