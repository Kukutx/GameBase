class_name StorageMenu
extends MenuLayer

## A storage chest: the player's inventory beside what the chest holds, an
## item moved across with a press, as many at a time as the amount the player
## picks (`amounts`: one, ten, the whole stack). Each list keeps its entry
## selected as it changes, so storing or taking again needs no new pick;
## an item gone from a list leaves the one now in its place selected. Store
## matching puts every item the chest already holds, all the player carries
## of it, onto its stacks (`store_matching()`), tools aside.

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
@onready var matching_button: Button = $Panel/VBox/Columns/InventoryColumn/StoreMatching

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
	matching_button.pressed.connect(store_matching)
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

# Fills `list` with `entries`, keeping its pick (`MenuLayer.refill_list()`).
func _fill(list: ItemList, entries: Array[Dictionary]) -> void:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var item_id := StringName(String(entry["id"]))
		var item := ItemData.find(item_id)
		rows.append({"text": "%s  x%d" % [tr(String(entry["display_name"])), entry["quantity"]], "key": item_id, "icon": item.icon if item != null else null})
	MenuLayer.refill_list(list, rows)

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

## Stores all the player carries of every item the chest already holds, but
## a tool, as far as the chest has room; how many moved.
func store_matching() -> int:
	var moved := 0
	var full := false
	for item_id: StringName in _matching_items():
		var held := InventoryState.get_quantity(item_id)
		var accepted := StorageState.store_item(_container_id, item_id, held, _max_slots)
		moved += accepted
		full = full or accepted < held
	if full:
		GameEvents.toast("Storage is full")
	_rebuild()
	return moved

# The items the player carries that the chest holds too, tools aside.
func _matching_items() -> Array[StringName]:
	var items: Array[StringName] = []
	if _container_id == &"":
		return items
	for entry: Dictionary in StorageState.get_entries(_container_id):
		var item_id := StringName(String(entry["id"]))
		var item := ItemData.find(item_id)
		if item != null and not item.is_tool() and InventoryState.get_quantity(item_id) > 0:
			items.append(item_id)
	return items

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
	matching_button.disabled = _matching_items().is_empty()
	if matching_button.disabled and matching_button.has_focus():
		MenuLayer.focus(inventory_list if inventory_list.item_count > 0 else close_button)
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
