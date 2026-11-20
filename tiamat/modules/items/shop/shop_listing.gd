class_name ShopListing
extends Resource

## An item a shop sells only while a condition holds, one of its
## `ShopData.listings`: Ember Depths' camp merchant brings in the Ember Blade
## once the player is a Delver. It lives in its shop's file, where the game's
## content check reads its condition (`GameRules.validate_content()`).

## The item it sells.
@export var item_id: StringName
## What the shop asks for one; 0, the item's own `buy_price`.
@export_range(0, 999999, 1) var price := 0
## When the shop sells it, a `GameRules` condition
## (`ACHIEVEMENT_UNLOCKED delver`); empty, always.
@export var condition := ""

## Whether the shop sells it now.
func is_open() -> bool:
	return condition.is_empty() or GameRules.check(condition)

## What the player reads of when the shop sells it ("Unlock Delver"), or
## nothing when it always does or the condition has no words
## (`GameRules.describe()`).
func describe_condition() -> PackedStringArray:
	return PackedStringArray() if condition.is_empty() else GameRules.describe(condition)
