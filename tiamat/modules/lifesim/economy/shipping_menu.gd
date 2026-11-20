class_name ShippingMenu
extends MenuLayer

## The shipping bin's menu: every item the player carries that the bin takes
## (`ShippingService.can_ship()`), with what one earns overnight, shipped as
## many at a press as the amount the player picks (`amounts`: one, ten, the
## whole stack), and what the bin will pay tonight. It opens on the item in
## hand where the bin takes it, and the list keeps its entry picked as stacks
## ship, so a press repeats a shipment. A game puts it in its HUD, and a
## `ShippingBin` opens it; without it, the bin ships the item in hand.

## The amounts one press ships, in the order the amount button steps through
## them, the first as the menu opens; 0 is all the player carries of the item.
## One amount hides the button.
@export var amounts: PackedInt32Array = PackedInt32Array([1, 10, 0])

@onready var title_label: Label = $Panel/VBox/Title
@onready var pending_label: Label = $Panel/VBox/Pending
@onready var item_list: ItemList = $Panel/VBox/Items
@onready var amount_button: Button = $Panel/VBox/Actions/Amount
@onready var ship_button: Button = $Panel/VBox/Actions/Ship
@onready var close_button: Button = $Panel/VBox/Actions/Close

var _amount_index := 0

func _init() -> void:
	super(&"shipping_menu")

func _ready() -> void:
	amount_button.pressed.connect(_next_amount)
	ship_button.pressed.connect(ship_selected)
	close_button.pressed.connect(close)
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	InventoryState.changed.connect(_refresh_if_open)
	ShippingState.shipment_changed.connect(_refresh_if_open)
	GameSettings.locale_changed.connect(_on_locale_changed)

## Shows what the player can ship, `picked` (the item in hand) picked first
## where it is one, else the first.
func open(picked: StringName = &"") -> void:
	_amount_index = 0
	item_list.clear()
	show_menu()
	_refresh()
	if item_list.item_count > 0:
		var at := 0
		for index: int in item_list.item_count:
			if item_list.get_item_metadata(index) == picked:
				at = index
		item_list.select(at)
		item_list.ensure_current_is_visible()
		_refresh_buttons()
		MenuLayer.focus(item_list)
	else:
		MenuLayer.focus(close_button)

## How many one press ships now; 0, all the player carries.
func get_amount() -> int:
	return maxi(amounts[_amount_index], 0) if _amount_index < amounts.size() else 1

## Ships the amount picked of the item picked; how many went in the bin.
func ship_selected() -> int:
	var item_id := _selected_item_id()
	if item_id == &"":
		return 0
	var held := InventoryState.get_quantity(item_id)
	var count := mini(held, get_amount()) if get_amount() > 0 else held
	if count <= 0 or not ShippingState.ship_item(item_id, count):
		return 0
	return count

func _refresh() -> void:
	title_label.text = tr("Shipping Bin")
	pending_label.text = tr("Shipping tonight: %dg") % ShippingState.get_pending_total()
	var rows: Array[Dictionary] = []
	for entry: Dictionary in InventoryState.get_entries():
		var item := ItemData.find(StringName(String(entry["id"])))
		if ShippingService.can_ship(item):
			rows.append({
				"text": tr("%s x%d — %dg each") % [tr(item.display_name), int(entry["quantity"]), item.sell_price],
				"key": item.id,
			})
	MenuLayer.refill_list(item_list, rows)
	_refresh_buttons()

# Keeps the buttons telling the amount, Ship open while an entry is picked;
# Ship closing with the focus hands it to the list, or to closing.
func _refresh_buttons() -> void:
	var amount := get_amount()
	amount_button.visible = amounts.size() > 1
	amount_button.text = tr("Amount: %d") % amount if amount > 0 else tr("Amount: All")
	ship_button.text = tr("Ship %d") % amount if amount > 0 else tr("Ship all")
	ship_button.disabled = _selected_item_id() == &""
	if ship_button.disabled and ship_button.has_focus():
		MenuLayer.focus(item_list if item_list.item_count > 0 else close_button)

func _selected_item_id() -> StringName:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return &""
	return StringName(String(item_list.get_item_metadata(int(selected[0]))))

# Steps to the next amount, keeping the list and the focus where they are.
func _next_amount() -> void:
	if amounts.size() < 2:
		return
	_amount_index = (_amount_index + 1) % amounts.size()
	_refresh_buttons()

func _refresh_if_open() -> void:
	if visible:
		_refresh()

func _on_locale_changed(_locale: String) -> void:
	_refresh_if_open()

func _on_item_selected(_index: int) -> void:
	_refresh_buttons()

func _on_item_activated(_index: int) -> void:
	ship_selected()
