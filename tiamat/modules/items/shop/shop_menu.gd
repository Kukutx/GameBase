class_name ShopMenu
extends MenuLayer

## A shop's counter: buys what the shop stocks and offers, and sells, one at a
## time, every item the inventory holds that has a sell price. Under the lists
## it tells of the item whose button has the focus: its description and what
## it does (`describe_item()`).

@onready var title_label: Label = $Panel/VBox/Title
@onready var money_label: Label = $Panel/VBox/Money
@onready var items_container: VBoxContainer = $Panel/VBox/Lists/Entries/Items
@onready var sell_title: Label = $Panel/VBox/Lists/Entries/SellTitle
@onready var sell_container: VBoxContainer = $Panel/VBox/Lists/Entries/SellItems
@onready var about_label: Label = $Panel/VBox/About
@onready var close_button: Button = $Panel/VBox/Close

var _shop: ShopData
# item id -> the button that sells one of it
var _sell_buttons: Dictionary[StringName, Button] = {}

func _init() -> void:
	super(&"shop_menu")

func _ready() -> void:
	close_button.pressed.connect(close)
	Wallet.money_changed.connect(_on_money_changed)
	InventoryState.changed.connect(_on_inventory_changed)
	# Two lines kept for it, so the lists keep their height as it changes.
	about_label.custom_minimum_size.y = about_label.get_line_height() * 2

func open(shop: ShopData) -> void:
	if shop == null:
		return
	_shop = shop
	show_menu()
	_rebuild()

func close() -> void:
	_shop = null
	super()

func _rebuild() -> void:
	for child: Node in items_container.get_children():
		child.queue_free()
	if _shop == null:
		return
	title_label.text = tr(_shop.display_name)
	about_label.text = ""
	money_label.text = tr("Money: %dg") % Wallet.money
	var ids: Array[String] = []
	for raw: Variant in _shop.get_stock().keys():
		ids.append(String(raw))
	ids.sort()
	var first_button: Button
	for raw_id: String in ids:
		var item_id := StringName(raw_id)
		var item := ItemData.find(item_id)
		if item == null:
			continue
		var price := _shop.get_buy_price(item)
		var button := MenuLayer.list_button()
		button.text = tr("Buy %s — %dg") % [tr(item.display_name), price]
		button.pressed.connect(_buy.bind(item_id))
		button.focus_entered.connect(_tell_about.bind(item))
		items_container.add_child(button)
		if first_button == null:
			first_button = button
	var context := _offer_context()
	for offer: ShopOffer in _shop.offers:
		var button := MenuLayer.list_button()
		button.text = offer.get_label(context)
		button.disabled = not offer.can_buy(context)
		button.pressed.connect(_buy_offer.bind(offer))
		button.focus_entered.connect(_tell_about.bind(null))
		items_container.add_child(button)
		if first_button == null and not button.disabled:
			first_button = button
	_refresh_sell_list()
	if first_button == null and not _sell_buttons.is_empty():
		first_button = sell_container.get_child(0) as Button
	MenuLayer.focus(first_button if first_button != null else close_button)

## What the counter tells of `item`: its description, then what it does
## (`ItemData.describe_effects()`), on a line of its own; "" for none.
static func describe_item(item: ItemData) -> String:
	if item == null:
		return ""
	var parts := PackedStringArray()
	if not item.description.is_empty():
		parts.append(TranslationServer.translate(item.description))
	var effects := item.describe_effects()
	if not effects.is_empty():
		parts.append(ItemData.EFFECT_SEPARATOR.join(effects))
	return "\n".join(parts)

func _tell_about(item: ItemData) -> void:
	about_label.text = describe_item(item)

func _buy(item_id: StringName) -> void:
	ShopState.buy(_shop, item_id, 1)

func _buy_offer(offer: ShopOffer) -> void:
	ShopState.buy_offer(_shop, offer, _offer_context())
	_rebuild()

func _offer_context() -> Dictionary:
	var location := WorldLocationData.find_current(get_tree())
	return {"location_id": location.id if location != null else &""}

func _sell(item_id: StringName) -> void:
	ShopState.sell(item_id, 1)

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
		button.text = tr("Sell %s (%d) — %dg") % [tr(item.display_name), InventoryState.get_quantity(item.id), item.sell_price]
	sell_title.visible = not sellable.is_empty()
	if focus_index >= 0 and visible:
		var count := sell_container.get_child_count()
		var next := sell_container.get_child(mini(focus_index, count - 1)) as Button if count > 0 else close_button
		MenuLayer.focus(next)

func _on_money_changed(_amount: int) -> void:
	if visible:
		money_label.text = tr("Money: %dg") % Wallet.money

func _on_inventory_changed() -> void:
	if visible:
		_refresh_sell_list()
