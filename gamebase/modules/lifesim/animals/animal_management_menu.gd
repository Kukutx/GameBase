class_name AnimalManagementMenu
extends MenuLayer

@onready var title_label: Label = $Panel/VBox/Title
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var animal_select: OptionButton = $Panel/VBox/AnimalSelect
@onready var details_label: RichTextLabel = $Panel/VBox/Details
@onready var name_edit: LineEdit = $Panel/VBox/RenameRow/Name
@onready var rename_button: Button = $Panel/VBox/RenameRow/Rename
@onready var feed_row: HBoxContainer = $Panel/VBox/FeedRow
@onready var expansion_row: HBoxContainer = $Panel/VBox/ExpansionRow
@onready var sell_button: Button = $Panel/VBox/Actions/Sell
@onready var close_button: Button = $Panel/VBox/Actions/Close
@onready var confirm_sell: ConfirmationDialog = $ConfirmSell

var _location_id: StringName
var _selected_instance_id: StringName
## The feed and expansion button of each housing at the open location.
var _feed_buttons: Dictionary[StringName, Button] = {}
var _expansion_buttons: Dictionary[StringName, Button] = {}

func _init() -> void:
	super(&"animal_management_menu")

func _ready() -> void:
	animal_select.item_selected.connect(_on_animal_selected)
	rename_button.pressed.connect(_rename_selected)
	sell_button.pressed.connect(_request_sell)
	close_button.pressed.connect(close)
	confirm_sell.confirmed.connect(_sell_selected)
	AnimalState.ownership_changed.connect(_on_ownership_changed)
	AnimalState.housing_fed.connect(_on_housing_fed)
	FarmExpansionState.expansion_completed.connect(_on_expansion_completed)
	WorldClock.day_changed.connect(_on_day_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)

func open(location_id: StringName) -> void:
	_location_id = location_id
	show_menu()
	_rebuild_housing_rows()
	_rebuild()
	_focus_primary_control()

func _rebuild() -> void:
	var previous := _selected_instance_id
	animal_select.clear()
	var records := AnimalState.get_owned(_location_id)
	for record: Dictionary in records:
		var instance_id := StringName(String(record.get("instance_id", "")))
		var data := FarmAnimalData.find(StringName(String(record.get("animal_id", ""))))
		if instance_id == &"" or data == null:
			continue
		var custom_name := String(record.get("custom_name", ""))
		var display_name := custom_name if not custom_name.is_empty() else tr(data.display_name)
		animal_select.add_item("%s · %s" % [display_name, tr(data.display_name)])
		animal_select.set_item_metadata(animal_select.item_count - 1, String(instance_id))
		if instance_id == previous:
			animal_select.select(animal_select.item_count - 1)

	if animal_select.item_count > 0:
		if animal_select.selected < 0:
			animal_select.select(0)
		_selected_instance_id = StringName(String(animal_select.get_item_metadata(animal_select.selected)))
	else:
		_selected_instance_id = &""
	_refresh_summary()
	_refresh_selected()

## One feed and one expansion button for each housing at the open location.
func _rebuild_housing_rows() -> void:
	for row: HBoxContainer in [feed_row, expansion_row]:
		for child: Node in row.get_children():
			row.remove_child(child)
			child.queue_free()
	_feed_buttons.clear()
	_expansion_buttons.clear()
	for housing_id: StringName in AnimalState.get_housing_ids(_location_id):
		_feed_buttons[housing_id] = _add_row_button(feed_row, _feed_housing.bind(housing_id))
		_expansion_buttons[housing_id] = _add_row_button(expansion_row, _purchase_next_expansion.bind(housing_id))

func _add_row_button(row: HBoxContainer, action: Callable) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	row.add_child(button)
	return button

func _focus_primary_control() -> void:
	if animal_select.item_count > 0:
		animal_select.grab_focus()
		return
	for button: Button in _feed_buttons.values() + _expansion_buttons.values():
		if not button.disabled:
			button.grab_focus()
			return
	close_button.grab_focus()

func _refresh_summary() -> void:
	title_label.text = tr("Animal Ledger")
	var parts := PackedStringArray()
	for housing_id: StringName in _feed_buttons:
		parts.append("%s %d/%d" % [tr(AnimalState.get_housing_name(housing_id)), AnimalState.get_housing_occupancy(housing_id), AnimalState.get_housing_capacity(housing_id)])
	for item_id: StringName in AnimalState.get_feed_item_ids(_location_id):
		var item := ItemData.find(item_id)
		parts.append("%s %d" % [tr(item.display_name) if item != null else String(item_id), InventoryState.get_quantity(item_id)])
	summary_label.text = " · ".join(parts)
	for housing_id: StringName in _feed_buttons:
		var needs := AnimalState.get_feed_needs(housing_id)
		var unfed := 0
		var can_feed := false
		for item_id: StringName in needs:
			unfed += needs[item_id]
			can_feed = can_feed or InventoryState.has_item(item_id)
		var feed_button := _feed_buttons[housing_id]
		feed_button.text = tr("Feed %s (%d)") % [tr(AnimalState.get_housing_name(housing_id)), unfed]
		feed_button.disabled = not can_feed
		_refresh_expansion_button(_expansion_buttons[housing_id], housing_id)

func _refresh_selected() -> void:
	var record := AnimalState.get_record(_selected_instance_id)
	if record.is_empty():
		details_label.text = tr("No animals owned here.")
		name_edit.text = ""
		rename_button.disabled = true
		sell_button.disabled = true
		return
	var data := FarmAnimalData.find(StringName(String(record.get("animal_id", ""))))
	if data == null:
		return
	var custom_name := String(record.get("custom_name", ""))
	var display_name := custom_name if not custom_name.is_empty() else tr(data.display_name)
	name_edit.text = display_name
	# A name typed by the player is inserted into BBCode below as plain text.
	var details_name := display_name.replace("[", "[lb]")
	var state_raw: Variant = WorldState.get_value(StringName("animal:%s" % String(_selected_instance_id)), {})
	var state: Dictionary = state_raw if state_raw is Dictionary else {}
	var happiness := int(state.get("happiness", 50))
	var fed_today := int(state.get("last_fed_day", 0)) >= WorldClock.day
	var last_product_day := int(state.get("last_product_day", WorldClock.day))
	var product_ready := fed_today and WorldClock.day - last_product_day >= data.product_interval_days
	var product := ItemData.find(data.product_item_id)
	var product_name := tr(product.display_name) if product != null else tr("None")
	details_label.text = tr("[b]%s[/b]\nSpecies: %s\nHousing: %s\nHappiness: %d/100\nFed today: %s\nProduct: %s%s") % [
		details_name,
		tr(data.display_name),
		tr(AnimalState.get_housing_name(StringName(String(record.get("housing_id", ""))))),
		happiness,
		tr("Yes") if fed_today else tr("No"),
		product_name,
		tr(" · ready") if product_ready else "",
	]
	rename_button.disabled = false
	sell_button.disabled = false
	sell_button.text = tr("Sell %s · %dg") % [display_name, int(round(float(data.purchase_price) * 0.5))]

func _on_animal_selected(index: int) -> void:
	if index < 0 or index >= animal_select.item_count:
		return
	_selected_instance_id = StringName(String(animal_select.get_item_metadata(index)))
	_refresh_selected()

func _rename_selected() -> void:
	if AnimalState.rename_animal(_selected_instance_id, name_edit.text):
		_rebuild()
	else:
		GameEvents.toast(tr("Animal name must be 1–20 characters"))

func _request_sell() -> void:
	var record := AnimalState.get_record(_selected_instance_id)
	if record.is_empty():
		return
	var data := FarmAnimalData.find(StringName(String(record.get("animal_id", ""))))
	if data == null:
		return
	var display_name := String(record.get("custom_name", ""))
	if display_name.is_empty():
		display_name = tr(data.display_name)
	confirm_sell.dialog_text = tr("Sell %s for %dg? This cannot be undone.") % [display_name, int(round(float(data.purchase_price) * 0.5))]
	confirm_sell.popup_centered()

func _sell_selected() -> void:
	AnimalState.sell_animal(_selected_instance_id)
	_selected_instance_id = &""
	_rebuild()

func _feed_housing(housing_id: StringName) -> void:
	var fed := AnimalState.feed_housing(housing_id)
	GameEvents.toast(tr_n("Fed %d animal", "Fed %d animals", fed) % fed if fed > 0 else tr("No animals were fed"))
	_refresh_summary()
	_refresh_selected()

func _refresh_expansion_button(button: Button, housing_id: StringName) -> void:
	var expansion := FarmExpansionState.get_next_expansion_for_housing(housing_id)
	if expansion == null:
		button.text = tr("%s Maxed") % tr(AnimalState.get_housing_name(housing_id))
		button.tooltip_text = tr("Maximum housing capacity reached")
		button.disabled = true
		return
	button.text = "%s · %dg" % [tr(expansion.display_name), expansion.money_cost]
	var requirements := PackedStringArray()
	for raw_id: Variant in expansion.materials.keys():
		var item_id := StringName(String(raw_id))
		var item := ItemData.find(item_id)
		requirements.append("%s x%d" % [tr(item.display_name) if item != null else tr(String(item_id).capitalize()), int(expansion.materials[raw_id])])
	button.tooltip_text = "%s\n%s" % [tr(expansion.description), " · ".join(requirements)]
	button.disabled = not FarmExpansionState.can_purchase(expansion.id)

func _purchase_next_expansion(housing_id: StringName) -> void:
	var expansion := FarmExpansionState.get_next_expansion_for_housing(housing_id)
	if expansion == null:
		return
	FarmExpansionState.purchase(expansion.id)
	_refresh_summary()

func _on_expansion_completed(_expansion_id: StringName, _housing_id: StringName, _capacity: int) -> void:
	if visible:
		_refresh_summary()

func _on_ownership_changed(location_id: StringName) -> void:
	if visible and location_id == _location_id:
		_rebuild()

func _on_housing_fed(_housing_id: StringName, _count: int) -> void:
	if visible:
		_refresh_summary()
		_refresh_selected()

func _on_day_changed(_day: int) -> void:
	if visible:
		_refresh_summary()
		_refresh_selected()

func _on_locale_changed(_locale: String) -> void:
	if visible:
		_rebuild()
