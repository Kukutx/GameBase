class_name HotbarService
extends Node

## The player's quick-select slots: which item id sits in each slot and which
## slot is selected. Slots hold item ids, not items; the inventory owns the items.

signal changed
signal selected_slot_changed(index: int, item_id: StringName)

const SLOT_COUNT := 9

var slots: Array[StringName] = default_slots()
var selected_slot := 0

## The game's starting hotbar (`GameDefinition.start_hotbar`), padded to
## `SLOT_COUNT` slots.
static func default_slots() -> Array[StringName]:
	var result: Array[StringName] = GameDefinition.current().start_hotbar.duplicate()
	result.resize(SLOT_COUNT)
	return result

func select_slot(index: int) -> void:
	if slots.is_empty():
		selected_slot = 0
		return
	var next := clampi(index, 0, slots.size() - 1)
	if next == selected_slot:
		return
	selected_slot = next
	selected_slot_changed.emit(selected_slot, get_selected_item_id())

func cycle_slot(direction: int) -> void:
	if slots.is_empty() or direction == 0:
		return
	selected_slot = posmod(selected_slot + direction, slots.size())
	selected_slot_changed.emit(selected_slot, get_selected_item_id())

func set_slot_item(index: int, item_id: StringName) -> bool:
	if index < 0 or index >= slots.size():
		return false
	if slots[index] == item_id:
		return true
	slots[index] = item_id
	changed.emit()
	if index == selected_slot:
		selected_slot_changed.emit(selected_slot, get_selected_item_id())
	return true

## Puts `item_id` in the first free slot unless a slot already holds it; returns
## the slot, or -1 when every slot is taken.
func ensure_item(item_id: StringName, select := false) -> int:
	if item_id == &"":
		return -1
	var existing := slots.find(item_id)
	if existing >= 0:
		if select:
			select_slot(existing)
		return existing
	var empty := slots.find(&"")
	if empty < 0:
		return -1
	set_slot_item(empty, item_id)
	if select:
		select_slot(empty)
	return empty

func get_selected_item_id() -> StringName:
	if selected_slot < 0 or selected_slot >= slots.size():
		return &""
	return slots[selected_slot]

func get_selected_item() -> ItemData:
	return ItemData.find(get_selected_item_id())

func get_text() -> String:
	var parts: PackedStringArray = []
	for index in slots.size():
		var item_id := slots[index]
		if item_id == &"":
			continue
		var item := ItemData.find(item_id)
		var label := tr(item.display_name) if item != null else String(item_id)
		var quantity := InventoryState.get_quantity(item_id)
		if item != null and item.kind != ItemData.Kind.TOOL:
			label += " x%d" % quantity
		var prefix := ">" if index == selected_slot else " "
		parts.append("%s%d:%s" % [prefix, index + 1, label])
	return "  ".join(parts)

func reset_new_game() -> void:
	selected_slot = 0
	slots = default_slots()
	_emit_all()

func to_save_data() -> Dictionary:
	var slot_strings: Array[String] = []
	for item_id: StringName in slots:
		slot_strings.append(String(item_id))
	return {"slots": slot_strings, "selected_slot": selected_slot}

func load_save_data(data: Dictionary) -> void:
	var loaded: Variant = data.get("slots", default_slots())
	slots.clear()
	if loaded is Array:
		for raw: Variant in loaded:
			var item_id := StringName(String(raw))
			# A binding to an item that is not current content would leave the slot
			# silently unusable.
			if item_id != &"" and ItemData.find(item_id) == null:
				item_id = &""
			slots.append(item_id)
	if slots.is_empty():
		slots = default_slots()
	while slots.size() < SLOT_COUNT:
		slots.append(&"")
	var raw_selected: Variant = data.get("selected_slot", 0)
	var selected := int(raw_selected) if raw_selected is int or raw_selected is float else 0
	selected_slot = clampi(selected, 0, maxi(slots.size() - 1, 0))
	_emit_all()

func _emit_all() -> void:
	changed.emit()
	selected_slot_changed.emit(selected_slot, get_selected_item_id())
