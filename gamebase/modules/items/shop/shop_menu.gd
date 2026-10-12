class_name ShopMenu
extends CanvasLayer

## A shop's counter: buys what the shop stocks and offers, and sells, one at a
## time, every item the inventory holds that has a sell price.

@onready var title_label: Label = $Panel/VBox/Title
@onready var money_label: Label = $Panel/VBox/Money
@onready var items_container: VBoxContainer = $Panel/VBox/Lists/Entries/Items
@onready var sell_title: Label = $Panel/VBox/Lists/Entries/SellTitle
@onready var sell_container: VBoxContainer = $Panel/VBox/Lists/Entries/SellItems
@onready var close_button: Button = $Panel/VBox/Close

var _shop: ShopData
# item id -> the button that sells one of it
var _sell_buttons: Dictionary[StringName, Button] = {}

func _ready() -> void:
	add_to_group("shop_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	PlayerState.money_changed.connect(_on_money_changed)
	InventoryState.changed.connect(_on_inventory_changed)

func open(shop: ShopData) -> void:
	if shop == null:
		return
	_shop = shop
	visible = true
	InputLock.lock(&"shop_menu", true, self)
	_rebuild()

func close() -> void:
	if not visible:
		return
	visible = false
	_shop = null
	InputLock.unlock(&"shop_menu")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for child: Node in items_container.get_children():
		child.queue_free()
	if _shop == null:
		return
	title_label.text = tr(_shop.display_name)
	money_label.text = tr("Money: %dg") % PlayerState.money
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
		var button := Button.new()
		button.text = tr("Buy %s — %dg") % [tr(item.display_name), price]
		button.pressed.connect(_buy.bind(item_id))
		items_container.add_child(button)
		if first_button == null:
			first_button = button
	var context := _offer_context()
	for offer: ShopOffer in _shop.offers:
		var button := Button.new()
		button.text = offer.get_label(context)
		button.disabled = not offer.can_buy(context)
		button.pressed.connect(_buy_offer.bind(offer))
		items_container.add_child(button)
		if first_button == null and not button.disabled:
			first_button = button
	_refresh_sell_list()
	if first_button == null and not _sell_buttons.is_empty():
		first_button = sell_container.get_child(0) as Button
	if first_button != null:
		first_button.grab_focus()
	else:
		close_button.grab_focus()

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
			button = Button.new()
			button.pressed.connect(_sell.bind(item.id))
			sell_container.add_child(button)
			_sell_buttons[item.id] = button
		sell_container.move_child(button, index)
		button.text = tr("Sell %s (%d) — %dg") % [tr(item.display_name), InventoryState.get_quantity(item.id), item.sell_price]
	sell_title.visible = not sellable.is_empty()
	if focus_index >= 0 and visible:
		var count := sell_container.get_child_count()
		var next := sell_container.get_child(mini(focus_index, count - 1)) as Button if count > 0 else close_button
		next.grab_focus()

func _on_money_changed(_amount: int) -> void:
	if visible:
		money_label.text = tr("Money: %dg") % PlayerState.money

func _on_inventory_changed() -> void:
	if visible:
		_refresh_sell_list()
