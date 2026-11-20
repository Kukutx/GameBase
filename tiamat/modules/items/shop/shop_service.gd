class_name GameShopService
extends Node

## Buying from shops and selling to them: it checks the price (`ShopData`), the
## player's money (`Wallet`) and the room in the inventory
## (`InventoryState`), moves the money and the items together, and tells the
## player the result with a toast.
##
## A purchase buys as many as the player can afford and carry, up to the number
## asked, and takes no money when nothing fits. An item sells at its
## `sell_price`, and one without a price cannot be sold. A shop's other offers
## (`ShopOffer`, such as an animal) buy themselves through `buy_offer()`. An
## item a shop sells so many of a day (`ShopData.daily_limits`) sells no more
## that day: what the player bought of it is kept in `WorldState`
## (`shop:<shop id>:<item id>`, the day and the count), so it saves with the
## world. `purchase_completed`, `offer_purchased` and `sale_completed` announce
## each trade.

signal purchase_completed(shop_id: StringName, item_id: StringName, quantity: int, total: int)
signal offer_purchased(shop_id: StringName, offer: ShopOffer)
signal sale_completed(item_id: StringName, quantity: int, total: int)

var _buy_busy := false
var _sell_busy := false

func buy(shop: ShopData, item_id: StringName, quantity: int = 1) -> int:
	if _buy_busy:
		return 0
	_buy_busy = true
	var result := _buy_internal(shop, item_id, quantity)
	_buy_busy = false
	return result

func _buy_internal(shop: ShopData, item_id: StringName, quantity: int = 1) -> int:
	if shop == null or quantity <= 0 or not shop.has_item(item_id):
		return 0
	var item := ItemData.find(item_id)
	if item == null:
		return 0
	var unit_price := shop.get_buy_price(item)
	if unit_price <= 0:
		return 0
	var left := get_left_today(shop, item_id)
	if left == 0:
		GameEvents.toast("Sold out for today")
		return 0
	var affordable := mini(quantity if left < 0 else mini(quantity, left), Wallet.money / unit_price)
	if affordable <= 0:
		GameEvents.toast("Not enough money")
		return 0
	var bought := mini(affordable, InventoryState.get_add_capacity(item))
	if bought <= 0:
		GameEvents.toast("Inventory is full")
		return 0
	var total := bought * unit_price
	if not Wallet.spend(total):
		return 0
	if not InventoryState.apply_transaction_atomic({}, {String(item.id): bought}):
		Wallet.add(total)
		GameEvents.toast("Inventory changed before the purchase completed")
		return 0
	if left > 0:
		WorldState.set_value(_sold_key(shop, item_id), {"day": WorldClock.day, "sold": _sold_today(shop, item_id) + bought})
	purchase_completed.emit(shop.id, item_id, bought, total)
	GameEvents.toastf("Bought %s x%d for %dg", [item.display_name, bought, total])
	return bought

## How many more of `item_id` `shop` sells today: -1 for an item without a
## daily limit (`ShopData.daily_limits`), else its limit less what the player
## bought there today, at least 0.
func get_left_today(shop: ShopData, item_id: StringName) -> int:
	var limit := shop.get_daily_limit(item_id)
	if limit <= 0:
		return -1
	return maxi(limit - _sold_today(shop, item_id), 0)

func _sold_key(shop: ShopData, item_id: StringName) -> StringName:
	return StringName("shop:%s:%s" % [shop.id, item_id])

# What the player bought of `item_id` at `shop` today; a record of another day
# counts none.
func _sold_today(shop: ShopData, item_id: StringName) -> int:
	var record: Variant = WorldState.get_value(_sold_key(shop, item_id), {})
	if not record is Dictionary or int((record as Dictionary).get("day", 0)) != WorldClock.day:
		return 0
	return maxi(int((record as Dictionary).get("sold", 0)), 0)

## Buys one of the shop's `offers`; `context` as `ShopOffer` describes.
func buy_offer(shop: ShopData, offer: ShopOffer, context: Dictionary) -> bool:
	if shop == null or offer == null or not shop.offers.has(offer) or not offer.buy(context):
		return false
	offer_purchased.emit(shop.id, offer)
	return true

func sell(item_id: StringName, quantity: int = 1) -> int:
	if _sell_busy:
		return 0
	_sell_busy = true
	var result := _sell_internal(item_id, quantity)
	_sell_busy = false
	return result

func _sell_internal(item_id: StringName, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	var item := ItemData.find(item_id)
	if item == null or item.sell_price <= 0:
		GameEvents.toast("That item cannot be sold")
		return 0
	var available := mini(quantity, InventoryState.get_quantity(item_id))
	if available <= 0:
		GameEvents.toast("You do not have that item")
		return 0
	if not InventoryState.remove_item(item_id, available):
		return 0
	var total := available * item.sell_price
	Wallet.add(total)
	sale_completed.emit(item_id, available, total)
	GameEvents.toastf("Sold %s x%d for %dg", [item.display_name, available, total])
	return available
