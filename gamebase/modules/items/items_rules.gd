class_name ItemsRules
extends RefCounted

## Condition and action keys of the items module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"HAS_ITEM", _has_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_COUNT])
	rules.register_action(&"ADD_ITEM", _add_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_COUNT])
	rules.register_action(&"REMOVE_ITEM", _remove_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_COUNT])

## HAS_ITEM <item> [count]: the inventory holds at least count (default 1).
static func _has_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.has_item(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)

## ADD_ITEM <item> [count]: adds every item, or none and fails when the
## inventory cannot take them all, so a failed action never gives a part.
static func _add_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.add_items_atomic({args[0]: int(args[1]) if args.size() > 1 else 1})

## REMOVE_ITEM <item> [count]: fails, removing nothing, when there are not enough.
static func _remove_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.remove_item(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)
