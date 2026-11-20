class_name ShopMenu
extends MenuLayer

## A shop's counter: buys what the shop stocks and offers, and sells every
## item the inventory holds that has a sell price, as many at a press as the
## amount the player picks (`amounts`: one, five, ten or all; a purchase stops
## at what they can afford and carry, a sale at what they hold). A purchase the
## player cannot make now (not one of the item affordable or carried, an offer
## its `ShopOffer.can_buy()` refuses) is dimmed, and opens again as soon as a
## sale or the bag makes room for it. Under the lists it tells of the item
## whose button has the focus: its description and what it does
## (`describe_item()`), or of the offer (`ShopOffer.describe()`).

## The amounts one press buys or sells, in the order the amount button steps
## through them, the first as the counter opens; 0 is all: as many as the
## player can buy now (`most_to_buy()`), every one they hold. One amount hides
## the button.
@export var amounts: PackedInt32Array = PackedInt32Array([1, 5, 10, 0])

@onready var title_label: Label = $Panel/VBox/Title
@onready var money_label: Label = $Panel/VBox/Money
@onready var amount_button: Button = $Panel/VBox/Amount
@onready var items_container: VBoxContainer = $Panel/VBox/Lists/Entries/Items
@onready var sell_title: Label = $Panel/VBox/Lists/Entries/SellTitle
@onready var sell_container: VBoxContainer = $Panel/VBox/Lists/Entries/SellItems
@onready var about_label: Label = $Panel/VBox/About
@onready var close_button: Button = $Panel/VBox/Close

var _shop: ShopData
# item id -> the button that buys it
var _buy_buttons: Dictionary[StringName, Button] = {}
# offer -> the button that buys it
var _offer_buttons: Dictionary[ShopOffer, Button] = {}
# item id -> the button that sells it
var _sell_buttons: Dictionary[StringName, Button] = {}
var _amount_index := 0

func _init() -> void:
	super(&"shop_menu")

func _ready() -> void:
	close_button.pressed.connect(close)
	amount_button.pressed.connect(_next_amount)
	Wallet.money_changed.connect(_on_money_changed)
	InventoryState.changed.connect(_on_inventory_changed)
	# A purchase counts toward a daily limit once it is made.
	ShopState.purchase_completed.connect(_on_purchase_completed)
	# Two lines kept for it, so the lists keep their height as it changes.
	about_label.custom_minimum_size.y = about_label.get_line_height() * 2

func open(shop: ShopData) -> void:
	if shop == null:
		return
	_shop = shop
	_amount_index = 0
	show_menu()
	_rebuild()

## How many one press buys or sells now; 0, all.
func get_amount() -> int:
	return maxi(amounts[_amount_index], 0) if _amount_index < amounts.size() else 1

## How many of `item` the player can buy at `shop` now: what their money
## pays for, the bag holds and the shop has left today.
static func most_to_buy(shop: ShopData, item: ItemData) -> int:
	var price := shop.get_buy_price(item)
	if price <= 0:
		return 0
	var most := mini(Wallet.money / price, InventoryState.get_add_capacity(item))
	var left := ShopState.get_left_today(shop, item.id)
	return mini(most, left) if left >= 0 else most

# The text of the amount button.
func _amount_text() -> String:
	return tr("Amount: %d") % get_amount() if get_amount() > 0 else tr("Amount: All")

func close() -> void:
	_shop = null
	super()

## Builds the purchases' buttons; `keep_focus`, on the purchase whose button
## had it (`MenuLayer.focus_kept()`), else on the first the player can make.
func _rebuild(keep_focus := false) -> void:
	var kept: Variant = MenuLayer.focused_key(self) if keep_focus else null
	for child: Node in items_container.get_children():
		child.queue_free()
	_buy_buttons.clear()
	_offer_buttons.clear()
	if _shop == null:
		return
	amount_button.visible = amounts.size() > 1
	amount_button.text = _amount_text()
	title_label.text = tr(_shop.display_name)
	about_label.text = ""
	money_label.text = tr("Money: %dg") % Wallet.money
	var ids: Array[String] = []
	for raw: Variant in _shop.get_stock().keys():
		ids.append(String(raw))
	ids.sort()
	var buttons: Array[Button] = []
	for raw_id: String in ids:
		var item_id := StringName(raw_id)
		var item := ItemData.find(item_id)
		if item == null:
			continue
		var button := MenuLayer.list_button()
		button.set_meta(MenuLayer.FOCUS_KEY, "item:%s" % item_id)
		_buy_buttons[item_id] = button
		button.pressed.connect(_buy.bind(item_id))
		button.focus_entered.connect(_tell_about.bind(item))
		items_container.add_child(button)
		buttons.append(button)
	for offer: ShopOffer in _shop.offers:
		var button := MenuLayer.list_button()
		button.set_meta(MenuLayer.FOCUS_KEY, "offer:%s" % offer.get_key())
		_offer_buttons[offer] = button
		button.pressed.connect(_buy_offer.bind(offer))
		button.focus_entered.connect(_tell_of_offer.bind(offer))
		items_container.add_child(button)
		buttons.append(button)
	_refresh_buy_list()
	_refresh_sell_list()
	for child: Node in sell_container.get_children():
		buttons.append(child as Button)
	MenuLayer.focus_kept(buttons, kept, close_button)

## What the counter tells of `item` (`ItemData.describe()`); "" for none.
static func describe_item(item: ItemData) -> String:
	return item.describe() if item != null else ""

func _tell_about(item: ItemData) -> void:
	about_label.text = describe_item(item)

func _tell_of_offer(offer: ShopOffer) -> void:
	about_label.text = offer.describe(_offer_context())

func _buy(item_id: StringName) -> void:
	var item := ItemData.find(item_id)
	if item != null:
		ShopState.buy(_shop, item_id, get_amount() if get_amount() > 0 else most_to_buy(_shop, item))

## Keeps each purchase's button telling its price at the amount picked, and
## open only while the player can make it now: one of an item they can afford
## and carry, an offer its `ShopOffer.can_buy()` lets them buy.
func _refresh_buy_list() -> void:
	if _shop == null:
		return
	for item_id: StringName in _buy_buttons:
		var item := ItemData.find(item_id)
		if item != null:
			_buy_buttons[item_id].text = _buy_label(item)
			_buy_buttons[item_id].disabled = not can_buy_one(_shop, item)
	var context := _offer_context()
	for offer: ShopOffer in _offer_buttons:
		_offer_buttons[offer].text = offer.get_label(context)
		_offer_buttons[offer].disabled = not offer.can_buy(context)

## Whether the player can buy one `item` at `shop` now: it has a price, the
## shop has one left today, they afford it and the bag has room for it.
static func can_buy_one(shop: ShopData, item: ItemData) -> bool:
	var price := shop.get_buy_price(item)
	return price > 0 and ShopState.get_left_today(shop, item.id) != 0 and Wallet.can_afford(price) and InventoryState.get_add_capacity(item) > 0

# A purchase's button: the item and the price of one, or of the amount, and
# how many are left today of an item the shop sells so many of a day.
func _buy_label(item: ItemData) -> String:
	var price := _shop.get_buy_price(item)
	var amount := get_amount() if get_amount() > 0 else most_to_buy(_shop, item)
	var left := ShopState.get_left_today(_shop, item.id)
	if amount == 1 or (get_amount() == 0 and amount < 1):
		if left >= 0:
			return tr("Buy %s — %dg (%d left today)") % [tr(item.display_name), price, left]
		return tr("Buy %s — %dg") % [tr(item.display_name), price]
	if left >= 0:
		return tr("Buy %s x%d — %dg (%d left today)") % [tr(item.display_name), amount, price * amount, left]
	return tr("Buy %s x%d — %dg") % [tr(item.display_name), amount, price * amount]

# A sale's button: the item, how many the player holds and what one sells
# for, or as many of the amount as they hold.
func _sell_label(item: ItemData) -> String:
	var held := InventoryState.get_quantity(item.id)
	var amount := mini(get_amount(), held) if get_amount() > 0 else held
	if get_amount() == 1:
		return tr("Sell %s (%d) — %dg") % [tr(item.display_name), held, item.sell_price]
	return tr("Sell %s (%d) x%d — %dg") % [tr(item.display_name), held, amount, item.sell_price * amount]

# Steps to the next amount, keeping the buttons and the focus where they are.
func _next_amount() -> void:
	if amounts.size() < 2 or _shop == null:
		return
	_amount_index = (_amount_index + 1) % amounts.size()
	amount_button.text = _amount_text()
	_refresh_buy_list()
	_refresh_sell_list()

func _buy_offer(offer: ShopOffer) -> void:
	ShopState.buy_offer(_shop, offer, _offer_context())
	_rebuild(true)

func _offer_context() -> Dictionary:
	var location := WorldLocationData.find_current(get_tree())
	return {"location_id": location.id if location != null else &""}

func _sell(item_id: StringName) -> void:
	ShopState.sell(item_id, get_amount() if get_amount() > 0 else InventoryState.get_quantity(item_id))

## Keeps one sell button per sellable item the inventory holds, in the
## inventory's order, so a sale changes the buttons in place and the focus
## stays on the list.
func _refresh_sell_list() -> void:
	var sellable: Array[ItemData] = []
	for entry: Dictionary in InventoryState.get_entries():
		var item := ItemData.find(StringName(String(entry["id"])))
		if item != null and item.sell_price > 0:
			sellable.append(item)
	var focused := get_viewport().gui_get_focus_owner()
	var focus_index := -1
	for item_id: StringName in _sell_buttons.keys():
		if sellable.any(func(item: ItemData) -> bool: return item.id == item_id):
			continue
		var gone := _sell_buttons[item_id]
		if gone == focused:
			focus_index = gone.get_index()
		sell_container.remove_child(gone)
		gone.queue_free()
		_sell_buttons.erase(item_id)
	for index: int in sellable.size():
		var item := sellable[index]
		var button: Button = _sell_buttons.get(item.id)
		if button == null:
			button = MenuLayer.list_button()
			button.pressed.connect(_sell.bind(item.id))
			button.focus_entered.connect(_tell_about.bind(item))
			sell_container.add_child(button)
			_sell_buttons[item.id] = button
		sell_container.move_child(button, index)
		button.text = _sell_label(item)
	sell_title.visible = not sellable.is_empty()
	if focus_index >= 0 and visible:
		var count := sell_container.get_child_count()
		var next := sell_container.get_child(mini(focus_index, count - 1)) as Button if count > 0 else close_button
		MenuLayer.focus(next)

func _on_money_changed(_amount: int) -> void:
	if visible:
		money_label.text = tr("Money: %dg") % Wallet.money
		_refresh_buy_list()

func _on_purchase_completed(_shop_id: StringName, _item_id: StringName, _quantity: int, _total: int) -> void:
	if visible:
		_refresh_buy_list()

func _on_inventory_changed() -> void:
	if visible:
		_refresh_buy_list()
		_refresh_sell_list()
