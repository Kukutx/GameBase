class_name MiningNode
extends Interactable

signal depleted(node_id: StringName)
signal respawned(node_id: StringName)

const PICKUP_SCENE := preload("res://gamebase/modules/items/items/item_pickup.tscn")

@export var data: MiningNodeData
@export var persistent_id: StringName

@onready var rock_visual: Polygon2D = $Rock
@onready var state_label: Label = $StateLabel

var durability_left := 1
var is_depleted := false
var depleted_day := 0
var pending_drop_quantity := 0
var _drop_pickup: WorldItemPickup
var _action_busy := false

func _ready() -> void:
	_load_state()
	if data != null and durability_left <= 0 and not is_depleted:
		durability_left = data.durability
	WorldClock.day_changed.connect(_on_day_changed)
	_refresh_visual()
	_restore_pending_drop.call_deferred()

func use_item(item_id: StringName) -> bool:
	if _action_busy:
		return false
	_action_busy = true
	var result := _use_item_internal(item_id)
	_action_busy = false
	return result

func _use_item_internal(item_id: StringName) -> bool:
	if data == null or is_depleted:
		GameEvents.toast("Nothing left to mine here")
		return false
	var item := ItemData.find(item_id)
	if item == null or not item.is_tool() or item.tool_action != ItemData.ACTION_MINE:
		GameEvents.toastf("Use a pickaxe on %s", [data.display_name])
		return false
	if item.tool_power < data.required_tool_power:
		GameEvents.toast("This pickaxe is not strong enough")
		return false
	if not InventoryState.has_item(item.id, 1):
		GameEvents.toastf("You do not have %s", [item.display_name])
		return false
	var energy_multiplier := GameStats.get_multiplier(&"tool_energy") * GameStats.get_multiplier(&"mining_energy")
	var energy_cost := maxi(int(floor(float(data.energy_cost) * energy_multiplier)), 1)
	if not PlayerState.consume_energy(energy_cost):
		GameEvents.toast("Not enough energy")
		return false
	durability_left = maxi(durability_left - item.tool_power, 0)
	if durability_left <= 0:
		_break_node()
	else:
		_persist()
		_refresh_visual()
		GameEvents.toastf("%s · %d hits left", [data.display_name, durability_left])
	return true

func get_state_data() -> Dictionary:
	return {
		"durability_left": durability_left,
		"depleted": is_depleted,
		"depleted_day": depleted_day,
		"pending_drop_quantity": pending_drop_quantity,
	}

func load_state_data(state: Dictionary, persist := true) -> void:
	var default_durability := data.durability if data != null else 1
	var current_day := maxi(WorldClock.day, 1)
	durability_left = clampi(SaveValues.whole_number_or(state.get("durability_left", default_durability), default_durability), 0, default_durability)
	var raw_depleted: Variant = state.get("depleted", false)
	is_depleted = raw_depleted is bool and bool(raw_depleted)
	if is_depleted:
		depleted_day = clampi(SaveValues.whole_number_or(state.get("depleted_day", current_day), current_day), 1, current_day)
		durability_left = 0
	else:
		depleted_day = 0
		if durability_left <= 0:
			durability_left = default_durability
	pending_drop_quantity = SaveValues.count(state.get("pending_drop_quantity", 0))
	if persist:
		_persist()
	_refresh_visual()

func _break_node() -> void:
	var item := ItemData.find(data.drop_item_id)
	if item == null:
		return
	var remaining := InventoryState.add_item(item, data.drop_quantity)
	if remaining > 0:
		pending_drop_quantity += remaining
	is_depleted = true
	depleted_day = WorldClock.day
	durability_left = 0
	_persist()
	if pending_drop_quantity > 0:
		_spawn_drop(item, pending_drop_quantity)
	_refresh_visual()
	depleted.emit(data.id)
	LifesimEvents.resource_mined.emit(data.id, item.id, data.drop_quantity)
	GameEvents.toastf("Mined %s x%d", [item.display_name, data.drop_quantity])

func _spawn_drop(item: ItemData, quantity: int) -> void:
	if quantity <= 0 or get_tree().current_scene == null:
		return
	if is_instance_valid(_drop_pickup):
		_drop_pickup.set_quantity(quantity)
		return
	var pickup := _make_drop_pickup(item, quantity)
	if pickup == null:
		return
	_drop_pickup = pickup
	pickup.items_collected.connect(_on_pending_drop_collected)
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector2(10, 0)

func _make_drop_pickup(item: ItemData, quantity: int) -> WorldItemPickup:
	if item == null or quantity <= 0:
		return null
	var pickup := PICKUP_SCENE.instantiate() as WorldItemPickup
	if pickup == null:
		return null
	pickup.item = item
	pickup.quantity = quantity
	pickup.counts_as_forage = false
	return pickup

func _on_pending_drop_collected(_item_id: StringName, _collected: int, remaining: int) -> void:
	pending_drop_quantity = maxi(remaining, 0)
	_persist()
	if pending_drop_quantity <= 0:
		_drop_pickup = null

func _restore_pending_drop() -> void:
	if pending_drop_quantity <= 0 or data == null:
		return
	var item := ItemData.find(data.drop_item_id)
	if item != null:
		_spawn_drop(item, pending_drop_quantity)

func _on_day_changed(day: int) -> void:
	if not is_depleted or data == null:
		return
	if day - depleted_day < data.respawn_days:
		return
	is_depleted = false
	depleted_day = 0
	durability_left = data.durability
	_persist()
	_refresh_visual()
	respawned.emit(data.id)

func _refresh_visual() -> void:
	if data == null:
		prompt_text = "Rock"
		return
	rock_visual.color = data.visual_color
	rock_visual.modulate.a = 0.20 if is_depleted else 1.0
	state_label.visible = not is_depleted
	state_label.text = "%s %d/%d" % [tr(data.display_name), durability_left, data.durability]
	enabled = not is_depleted
	collision_layer = 16 if enabled else 0
	monitorable = enabled
	set_prompt("Mine %s", [data.display_name])

func _persist() -> void:
	if persistent_id == &"":
		return
	WorldState.set_value(_state_key(), get_state_data())

func _load_state() -> void:
	if data == null:
		return
	durability_left = data.durability
	if persistent_id == &"":
		return
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if raw is Dictionary and not raw.is_empty():
		load_state_data(raw, false)
	if is_depleted and WorldClock.day - depleted_day >= data.respawn_days:
		is_depleted = false
		depleted_day = 0
		durability_left = data.durability
		_persist()

func _state_key() -> StringName:
	return StringName("mining:%s" % String(persistent_id))

## The world state the node saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_state_key())]) if persistent_id != &"" else PackedStringArray()
