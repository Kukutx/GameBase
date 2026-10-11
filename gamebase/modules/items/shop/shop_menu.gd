class_name ShopMenu
extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/Title
@onready var money_label: Label = $Panel/VBox/Money
@onready var items_container: VBoxContainer = $Panel/VBox/Items
@onready var sell_button: Button = $Panel/VBox/SellSelected
@onready var close_button: Button = $Panel/VBox/Close

var _shop: ShopData

func _ready() -> void:
	add_to_group("shop_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	sell_button.pressed.connect(_sell_selected)
	close_button.pressed.connect(close)
	PlayerState.money_changed.connect(_on_money_changed)
	InventoryState.changed.connect(_refresh_sell_button)
	PlayerState.selected_slot_changed.connect(_on_selected_changed)

func open(shop: ShopData) -> void:
	if shop == null:
		return
	_shop = shop
	visible = true
	get_tree().paused = true
	_rebuild()

func close() -> void:
	if not visible:
		return
	visible = false
	_shop = null
	get_tree().paused = false

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
		var item := ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var price := _shop.get_buy_price(item)
		var button := Button.new()
		button.text = tr("Buy %s — %dg") % [tr(item.display_name), price]
		button.pressed.connect(_buy.bind(item_id))
		items_container.add_child(button)
		if first_button == null:
			first_button = button
	var location := ContentDB.get_current_location(get_tree())
	var location_id := location.id if location != null else &""
	for animal_id: StringName in _shop.animal_stock:
		var animal := ContentDB.get_farm_animal(animal_id)
		if animal == null:
			continue
		var button := Button.new()
		var slots := AnimalState.get_available_slots(location_id, animal.housing_type) if location_id != &"" else 0
		button.text = tr("Buy %s — %dg  ·  %s slots %d") % [tr(animal.display_name), animal.purchase_price, tr(String(animal.housing_type).capitalize()), slots]
		button.disabled = location_id == &"" or not AnimalState.can_purchase(animal_id, location_id)
		button.pressed.connect(_buy_animal.bind(animal_id))
		items_container.add_child(button)
		if first_button == null and not button.disabled:
			first_button = button
	_refresh_sell_button()
	if first_button != null:
		first_button.grab_focus()
	else:
		close_button.grab_focus()

func _buy(item_id: StringName) -> void:
	ShopState.buy(_shop, item_id, 1)
	money_label.text = tr("Money: %dg") % PlayerState.money
	_refresh_sell_button()

func _buy_animal(animal_id: StringName) -> void:
	var location := ContentDB.get_current_location(get_tree())
	if location == null:
		return
	ShopState.buy_animal(_shop, animal_id, location.id)
	_rebuild()

func _sell_selected() -> void:
	var item_id := PlayerState.get_selected_item_id()
	ShopState.sell(item_id, 1)
	money_label.text = tr("Money: %dg") % PlayerState.money
	_refresh_sell_button()

func _refresh_sell_button() -> void:
	if sell_button == null:
		return
	var item_id := PlayerState.get_selected_item_id()
	var item := ItemCatalog.get_item(item_id)
	var can_sell := item != null and item.sell_price > 0 and InventoryState.get_quantity(item_id) > 0
	sell_button.disabled = not can_sell
	if can_sell:
		sell_button.text = tr("Sell selected: %s — %dg") % [tr(item.display_name), item.sell_price]
	else:
		sell_button.text = tr("Sell selected")

func _on_money_changed(_amount: int) -> void:
	if visible:
		money_label.text = tr("Money: %dg") % PlayerState.money

func _on_selected_changed(_index: int, _item_id: StringName) -> void:
	_refresh_sell_button()
