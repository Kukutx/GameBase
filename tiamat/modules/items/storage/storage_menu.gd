class_name StorageMenu
extends MenuLayer

## A storage chest: the player's inventory beside what the chest holds, an
## item moved across with a press, as many at a time as the amount the player
## picks (`amounts`: one, ten, the whole stack). Each list keeps its entry
## selected as it changes, so storing or taking again needs no new pick;
## an item gone from a list leaves the one now in its place selected.

## The amounts one press stores or takes, in the order the amount button steps
## through them, the first as the chest opens; 0 is all of the item there is
## on that side. One amount hides the button.
@export var amounts: PackedInt32Array = PackedInt32Array([1, 10, 0])

@onready var title_label: Label = $Panel/VBox/Title
@onready var slots_label: Label = $Panel/VBox/Slots
@onready var amount_button: Button = $Panel/VBox/Actions/Amount
@onready var inventory_list: ItemList = $Panel/VBox/Columns/InventoryColumn/InventoryList
@onready var storage_list: ItemList = $Panel/VBox/Columns/StorageColumn/StorageList
@onready var store_button: Button = $Panel/VBox/Actions/StoreOne
@onready var take_button: Button = $Panel/VBox/Actions/TakeOne
@onready var close_button: Button = $Panel/VBox/Actions/Close

var _container_id: StringName
var _display_name := "Storage"
var _max_slots := 24
var _amount_index := 0

func _init() -> void:
	super(&"storage_menu")

func _ready() -> void:
	store_button.pressed.connect(_store_selected)
	take_button.pressed.connect(_take_selected)
	close_button.pressed.connect(close)
	amount_button.pressed.connect(_next_amount)
	inventory_list.item_selected.connect(_on_inventory_selected)
	storage_list.item_selected.connect(_on_storage_selected)
	inventory_list.item_activated.connect(_on_inventory_activated)
	storage_list.item_activated.connect(_on_storage_activated)
	InventoryState.changed.connect(_refresh_if_open)
	StorageState.container_changed.connect(_on_container_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)

func open(container_id: StringName, display_name: String, max_slots: int) -> void:
	if container_id == &"":
		return
	_container_id = container_id
	_display_name = display_name
	_max_slots = maxi(max_slots, 1)
	_amount_index = 0
	inventory_list.clear()
	storage_list.clear()
	show_menu()
	_rebuild()
	if inventory_list.item_count > 0:
		inventory_list.select(0)
		inventory_list.grab_focus()
	else:
		close_button.grab_focus()
	_refresh_buttons()

func close() -> void:
	_container_id = &""
	super()

## How many one press stores or takes now; 0, all there is.
func get_amount() -> int:
	return maxi(amounts[_amount_index], 0) if _amount_index < amounts.size() else 1

func _rebuild() -> void:
	if _container_id == &"":
		inventory_list.clear()
		storage_list.clear()
		return
	title_label.text = tr(_display_name)
	_fill(inventory_list, InventoryState.get_entries())
	_fill(storage_list, StorageState.get_entries(_container_id))
	_refresh_slots()
	_refresh_buttons()

# Fills `list` with `entries`, keeping selected the item that was, or, once it
# is gone from the list, the entry now in its place.
func _fill(list: ItemList, entries: Array[Dictionary]) -> void:
	var kept_id := _selected_item_id(list)
	var selected := list.get_selected_items()
	var kept_index := int(selected[0]) if not selected.is_empty() else -1
	list.clear()
	for entry: Dictionary in entries:
		var item_id := StringName(String(entry["id"]))
		var index := list.add_item("%s  x%d" % [tr(String(entry["display_name"])), entry["quantity"]])
		list.set_item_metadata(index, item_id)
		if kept_id != &"" and item_id == kept_id:
			kept_index = index
	if kept_index >= 0 and list.item_count > 0:
		list.select(mini(kept_index, list.item_count - 1))
		list.ensure_current_is_visible()

func _store_selected() -> void:
	var item_id := _selected_item_id(inventory_list)
	if item_id == &"":
		return
	var held := InventoryState.get_quantity(item_id)
	var wanted := mini(held, get_amount()) if get_amount() > 0 else held
	var accepted := StorageState.store_item(_container_id, item_id, wanted, _max_slots)
	if accepted < wanted:
		GameEvents.toast("Storage is full")
	_rebuild()

func _take_selected() -> void:
	var item_id := _selected_item_id(storage_list)
	if item_id == &"":
		return
	var stored := StorageState.get_quantity(_container_id, item_id)
	var wanted := mini(stored, get_amount()) if get_amount() > 0 else stored
	var accepted := StorageState.take_item(_container_id, item_id, wanted)
	if accepted < wanted:
		GameEvents.toast("Inventory is full")
	_rebuild()

# Steps to the next amount, keeping the lists and the focus where they are.
func _next_amount() -> void:
	if amounts.size() < 2:
		return
	_amount_index = (_amount_index + 1) % amounts.size()
	_refresh_buttons()

func _selected_item_id(list: ItemList) -> StringName:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return &""
	var raw: Variant = list.get_item_metadata(int(selected[0]))
	return raw as StringName if raw is StringName else StringName(String(raw))

func _refresh_slots() -> void:
	var used := StorageState.get_used_slots(_container_id)
	slots_label.text = tr("Storage slots: %d/%d") % [used, _max_slots]

# Keeps the buttons telling the amount, open while their list has an entry
# selected; a button that closes with the focus hands it to the other list,
# its first entry selected, or to closing.
func _refresh_buttons() -> void:
	var amount := get_amount()
	amount_button.visible = amounts.size() > 1
	amount_button.text = tr("Amount: %d") % amount if amount > 0 else tr("Amount: All")
	store_button.text = tr("Store %d →") % amount if amount > 0 else tr("Store all →")
	take_button.text = tr("← Take %d") % amount if amount > 0 else tr("← Take all")
	store_button.disabled = _selected_item_id(inventory_list) == &""
	take_button.disabled = _selected_item_id(storage_list) == &""
	for button: Button in [store_button, take_button]:
		if button.disabled and button.has_focus():
			var other := storage_list if button == store_button else inventory_list
			if other.item_count == 0:
				MenuLayer.focus(close_button)
				continue
			if not other.is_anything_selected():
				other.select(0)
				(take_button if button == store_button else store_button).disabled = false
			MenuLayer.focus(other)

func _on_locale_changed(_locale: String) -> void:
	_refresh_if_open()

func _refresh_if_open() -> void:
	if visible:
		_rebuild()

func _on_container_changed(container_id: StringName) -> void:
	if visible and container_id == _container_id:
		_rebuild()

func _on_inventory_selected(_index: int) -> void:
	_refresh_buttons()

func _on_storage_selected(_index: int) -> void:
	_refresh_buttons()

func _on_inventory_activated(_index: int) -> void:
	_store_selected()

func _on_storage_activated(_index: int) -> void:
	_take_selected()
