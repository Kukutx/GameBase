class_name GlobalPlayerState
extends Node

signal energy_changed(current: int, maximum: int)
signal health_changed(current: int, maximum: int)
signal money_changed(amount: int)
signal selected_slot_changed(index: int, item_id: StringName)
signal hotbar_changed

const DEFAULT_HOTBAR: Array[StringName] = [
	&"hoe",
	&"watering_can",
	&"pickaxe",
	&"rusty_sword",
	&"turnip_seeds",
	&"fishing_rod",
	&"berry",
	&"",
	&"",
]

@export_range(1, 999, 1) var max_energy := 100
@export_range(1, 999, 1) var max_health := 100

var energy := 100
var health := 100
var money := 500
var selected_slot := 0
var hotbar: Array[StringName] = DEFAULT_HOTBAR.duplicate()

func consume_energy(amount: int) -> bool:
	if amount <= 0:
		return true
	if energy < amount:
		return false
	energy -= amount
	energy_changed.emit(energy, max_energy)
	return true

func restore_energy(amount: int) -> void:
	if amount <= 0:
		return
	var next := mini(energy + amount, max_energy)
	if next == energy:
		return
	energy = next
	energy_changed.emit(energy, max_energy)

func set_energy(amount: int) -> void:
	var next := clampi(amount, 0, max_energy)
	if next == energy:
		return
	energy = next
	energy_changed.emit(energy, max_energy)

func restore_full_energy() -> void:
	energy = max_energy
	energy_changed.emit(energy, max_energy)

func take_damage(amount: int) -> bool:
	if amount <= 0 or health <= 0:
		return false
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	return true

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var next := mini(health + amount, max_health)
	if next == health:
		return
	health = next
	health_changed.emit(health, max_health)

func restore_full_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	if amount == 0:
		return true
	money -= amount
	money_changed.emit(money)
	return true

func lose_money(amount: int) -> int:
	var lost := mini(maxi(amount, 0), money)
	if lost <= 0:
		return 0
	money -= lost
	money_changed.emit(money)
	return lost

func select_slot(index: int) -> void:
	if hotbar.is_empty():
		selected_slot = 0
		return
	var next := clampi(index, 0, hotbar.size() - 1)
	if next == selected_slot:
		return
	selected_slot = next
	selected_slot_changed.emit(selected_slot, get_selected_item_id())

func cycle_slot(direction: int) -> void:
	if hotbar.is_empty() or direction == 0:
		return
	selected_slot = posmod(selected_slot + direction, hotbar.size())
	selected_slot_changed.emit(selected_slot, get_selected_item_id())

func set_hotbar_item(index: int, item_id: StringName) -> bool:
	if index < 0 or index >= hotbar.size():
		return false
	if hotbar[index] == item_id:
		return true
	hotbar[index] = item_id
	hotbar_changed.emit()
	if index == selected_slot:
		selected_slot_changed.emit(selected_slot, get_selected_item_id())
	return true

func ensure_hotbar_item(item_id: StringName, select := false) -> int:
	if item_id == &"":
		return -1
	var existing := hotbar.find(item_id)
	if existing >= 0:
		if select:
			select_slot(existing)
		return existing
	var empty := hotbar.find(&"")
	if empty < 0:
		return -1
	set_hotbar_item(empty, item_id)
	if select:
		select_slot(empty)
	return empty

func get_selected_item_id() -> StringName:
	if selected_slot < 0 or selected_slot >= hotbar.size():
		return &""
	return hotbar[selected_slot]

func get_selected_item() -> ItemData:
	return ItemCatalog.get_item(get_selected_item_id())

func get_hotbar_text() -> String:
	var parts: PackedStringArray = []
	for index in hotbar.size():
		var item_id := hotbar[index]
		if item_id == &"":
			continue
		var item := ItemCatalog.get_item(item_id)
		var label := tr(item.display_name) if item != null else String(item_id)
		var quantity := InventoryState.get_quantity(item_id)
		if item != null and item.kind != ItemData.Kind.TOOL:
			label += " x%d" % quantity
		var prefix := ">" if index == selected_slot else " "
		parts.append("%s%d:%s" % [prefix, index + 1, label])
	return "  ".join(parts)

func reset_new_game() -> void:
	energy = max_energy
	health = max_health
	money = 500
	selected_slot = 0
	hotbar = DEFAULT_HOTBAR.duplicate()
	energy_changed.emit(energy, max_energy)
	health_changed.emit(health, max_health)
	money_changed.emit(money)
	hotbar_changed.emit()
	selected_slot_changed.emit(selected_slot, get_selected_item_id())

func to_save_data() -> Dictionary:
	var hotbar_strings: Array[String] = []
	for item_id: StringName in hotbar:
		hotbar_strings.append(String(item_id))
	return {
		"max_energy": max_energy,
		"energy": energy,
		"max_health": max_health,
		"health": health,
		"money": money,
		"selected_slot": selected_slot,
		"hotbar": hotbar_strings,
	}

func load_save_data(data: Dictionary) -> void:
	max_energy = maxi(_safe_int(data.get("max_energy", 100), 100), 1)
	energy = clampi(_safe_int(data.get("energy", max_energy), max_energy), 0, max_energy)
	max_health = maxi(_safe_int(data.get("max_health", 100), 100), 1)
	health = clampi(_safe_int(data.get("health", max_health), max_health), 0, max_health)
	money = maxi(_safe_int(data.get("money", 500), 500), 0)
	var loaded_hotbar: Variant = data.get("hotbar", DEFAULT_HOTBAR)
	hotbar.clear()
	if loaded_hotbar is Array:
		for raw: Variant in loaded_hotbar:
			var item_id := StringName(String(raw))
			# Content updates may retire an item while its old inventory payload is
			# intentionally preserved as legacy data. Do not keep a dead hotbar binding
			# that makes the selected slot silently unusable.
			if item_id != &"" and ItemCatalog.get_item(item_id) == null:
				item_id = &""
			hotbar.append(item_id)
	if hotbar.is_empty():
		hotbar = DEFAULT_HOTBAR.duplicate()
	while hotbar.size() < 9:
		hotbar.append(&"")
	selected_slot = clampi(_safe_int(data.get("selected_slot", 0), 0), 0, maxi(hotbar.size() - 1, 0))
	energy_changed.emit(energy, max_energy)
	health_changed.emit(health, max_health)
	money_changed.emit(money)
	hotbar_changed.emit()
	selected_slot_changed.emit(selected_slot, get_selected_item_id())

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
