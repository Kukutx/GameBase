class_name StorageMenu
extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/Title
@onready var slots_label: Label = $Panel/VBox/Slots
@onready var inventory_list: ItemList = $Panel/VBox/Columns/InventoryColumn/InventoryList
@onready var storage_list: ItemList = $Panel/VBox/Columns/StorageColumn/StorageList
@onready var store_button: Button = $Panel/VBox/Actions/StoreOne
@onready var take_button: Button = $Panel/VBox/Actions/TakeOne
@onready var close_button: Button = $Panel/VBox/Actions/Close

var _container_id: StringName
var _display_name := "Storage"
var _max_slots := 24

func _ready() -> void:
	add_to_group("storage_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	store_button.pressed.connect(_store_selected)
	take_button.pressed.connect(_take_selected)
	close_button.pressed.connect(close)
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
	visible = true
	InputLock.lock(&"storage_menu", true, self)
	_rebuild()
	if inventory_list.item_count > 0:
		inventory_list.select(0)
		inventory_list.grab_focus()
	else:
		close_button.grab_focus()
	_refresh_buttons()

func close() -> void:
	if not visible:
		return
	visible = false
	_container_id = &""
	InputLock.unlock(&"storage_menu")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	inventory_list.clear()
	storage_list.clear()
	if _container_id == &"":
		return
	title_label.text = tr(_display_name)
	for entry: Dictionary in InventoryState.get_entries():
		var index := inventory_list.add_item("%s  x%d" % [tr(String(entry["display_name"])), entry["quantity"]])
		inventory_list.set_item_metadata(index, StringName(String(entry["id"])))
	for entry: Dictionary in StorageState.get_entries(_container_id):
		var index := storage_list.add_item("%s  x%d" % [tr(String(entry["display_name"])), entry["quantity"]])
		storage_list.set_item_metadata(index, StringName(String(entry["id"])))
	_refresh_slots()
	_refresh_buttons()

func _store_selected() -> void:
	var item_id := _selected_item_id(inventory_list)
	if item_id == &"":
		return
	var accepted := StorageState.store_item(_container_id, item_id, 1, _max_slots)
	if accepted <= 0:
		GameEvents.toast("Storage is full")
	_rebuild()

func _take_selected() -> void:
	var item_id := _selected_item_id(storage_list)
	if item_id == &"":
		return
	var accepted := StorageState.take_item(_container_id, item_id, 1)
	if accepted <= 0:
		GameEvents.toast("Inventory is full")
	_rebuild()

func _selected_item_id(list: ItemList) -> StringName:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return &""
	var raw: Variant = list.get_item_metadata(int(selected[0]))
	return raw as StringName if raw is StringName else StringName(String(raw))

func _refresh_slots() -> void:
	var used := StorageState.get_used_slots(_container_id)
	slots_label.text = tr("Storage slots: %d/%d") % [used, _max_slots]

func _refresh_buttons() -> void:
	store_button.disabled = _selected_item_id(inventory_list) == &""
	take_button.disabled = _selected_item_id(storage_list) == &""

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
