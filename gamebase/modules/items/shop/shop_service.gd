class_name GameShopService
extends Node

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
	var affordable := mini(quantity, PlayerState.money / unit_price)
	if affordable <= 0:
		GameEvents.toast("Not enough money")
		return 0
	var bought := mini(affordable, InventoryState.get_add_capacity(item))
	if bought <= 0:
		GameEvents.toast("Inventory is full")
		return 0
	var total := bought * unit_price
	if not PlayerState.spend_money(total):
		return 0
	if not InventoryState.apply_transaction_atomic({}, {String(item.id): bought}):
		PlayerState.add_money(total)
		GameEvents.toast("Inventory changed before the purchase completed")
		return 0
	purchase_completed.emit(shop.id, item_id, bought, total)
	GameEvents.toastf("Bought %s x%d for %dg", [item.display_name, bought, total])
	return bought

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
	PlayerState.add_money(total)
	sale_completed.emit(item_id, available, total)
	GameEvents.toastf("Sold %s x%d for %dg", [item.display_name, available, total])
	return available
