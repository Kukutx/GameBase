class_name ShopOffer
extends Resource

## Something a shop sells other than an item, listed in `ShopData.offers`.
##
## The module that owns a kind of goods subclasses this (an animal, a building
## upgrade, a service), so the shop sells it without knowing about it. `context`
## carries facts of the purchase: "location_id", where the player shops.

## Names the offer within its shop, so a shop does not list one twice.
func get_key() -> String:
	return ""

## The translated text of the offer's buy button.
func get_label(_context: Dictionary) -> String:
	return ""

func can_buy(_context: Dictionary) -> bool:
	return false

## Charges the player and hands over the goods. Returns whether it was bought.
func buy(_context: Dictionary) -> bool:
	return false

## What is wrong with the offer's data, such as an id `registry` does not hold.
func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	return PackedStringArray()
