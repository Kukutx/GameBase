class_name ItemsRules
extends RefCounted

## Condition and action keys of the items module (see `GameRulesService`):
## the inventory, item tags and money.

## Rule argument kind: a tag some item has (`ItemData.tags`).
const ARG_ITEM_TAG := &"item_tag"

static func register(rules: GameRulesService) -> void:
	rules.register_arg_kind(ARG_ITEM_TAG, _check_item_tag)
	rules.register_condition(&"HAS_ITEM", _has_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_COUNT])
	rules.register_condition(&"ITEM_TAG", _item_tag, 2, 2, [ItemData.KIND, ARG_ITEM_TAG])
	rules.register_action(&"ADD_ITEM", _add_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_COUNT])
	rules.register_action(&"REMOVE_ITEM", _remove_item, 1, 2, [ItemData.KIND, GameRulesService.ARG_COUNT])
	rules.register_condition(&"MONEY_AT_LEAST", _money_at_least, 1, 1, [GameRulesService.ARG_INT])
	rules.register_action(&"ADD_MONEY", _add_money, 1, 1, [GameRulesService.ARG_INT])

## HAS_ITEM <item> [count]: the inventory holds at least count (default 1).
static func _has_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.has_item(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)

## ITEM_TAG <item> <tag>: the item has the tag, as an objective that counts
## every fish caught asks of the event's item (`ITEM_TAG $item_id fish`).
static func _item_tag(args: PackedStringArray, _context: Dictionary) -> bool:
	return ItemData.has_tagged(ContentRegistry.active, StringName(args[0]), args[1])

static func _check_item_tag(value: String) -> String:
	for item: ItemData in ItemData.find_all():
		if item.has_tag(value):
			return ""
	return "no item has tag '%s'" % value

## ADD_ITEM <item> [count]: adds every item, or none and fails when the
## inventory cannot take them all, so a failed action never gives a part.
static func _add_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.add_items_atomic({args[0]: int(args[1]) if args.size() > 1 else 1})

## REMOVE_ITEM <item> [count]: fails, removing nothing, when there are not enough.
static func _remove_item(args: PackedStringArray, _context: Dictionary) -> bool:
	return InventoryState.remove_item(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)

## MONEY_AT_LEAST <n>: the player has at least n money.
static func _money_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return Wallet.money >= int(args[0])

## ADD_MONEY <n>: gives the player n money; an n of 0 or less gives nothing and
## takes nothing, and the action still succeeds.
static func _add_money(args: PackedStringArray, _context: Dictionary) -> bool:
	Wallet.add(int(args[0]))
	return true
