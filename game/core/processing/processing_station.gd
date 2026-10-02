class_name ProcessingStation
extends PlacedStructure

signal job_started(station_id: StringName, recipe_id: StringName, finish_at: int)
signal job_finished(station_id: StringName, recipe_id: StringName)
signal output_collected(station_id: StringName, item_id: StringName, quantity: int)

@export var station_id: StringName
@export var display_name := "Processing Station"
@export var recipe_ids: Array[StringName] = []

@onready var interactable: Interactable = $Interactable
@onready var state_label: Label = $StateLabel
@onready var body_visual: Polygon2D = $Body

var active_recipe_id: StringName
var finish_at := 0
var output_ready := false
var pending_output_item_id: StringName
var pending_output_quantity := 0
var pending_input_refund: Dictionary = {}
var _operation_busy := false

func configure_from_record(record: Dictionary) -> void:
	super.configure_from_record(record)
	if placement_id != &"":
		station_id = placement_id

func can_pack_up() -> bool:
	if active_recipe_id != &"" or output_ready:
		GameEvents.toast("Collect or finish the current job before packing this station")
		return false
	return true

func on_removed() -> void:
	if station_id != &"":
		WorldState.erase(_state_key())

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	WorldClock.minute_changed.connect(_on_time_changed)
	_load_state()
	_update_job()
	_refresh()

func interact(_actor: Node = null) -> void:
	_on_interacted(_actor)

func start_recipe(recipe_id: StringName) -> bool:
	if _operation_busy:
		return false
	_operation_busy = true
	var result := _start_recipe_internal(recipe_id)
	_operation_busy = false
	return result

func _start_recipe_internal(recipe_id: StringName) -> bool:
	if active_recipe_id != &"" or output_ready:
		return false
	var recipe := _get_recipe(recipe_id)
	if recipe == null or not recipe.can_start():
		return false
	if not InventoryState.apply_transaction_atomic(recipe.inputs, {}):
		return false
	active_recipe_id = recipe.id
	finish_at = _absolute_minute(WorldClock.day, WorldClock.minute_of_day) + recipe.process_minutes
	output_ready = false
	pending_output_item_id = recipe.output_item_id
	pending_output_quantity = recipe.output_quantity
	pending_input_refund = _build_input_refund_snapshot(recipe.inputs)
	_persist()
	_refresh()
	job_started.emit(station_id, recipe.id, finish_at)
	GameEvents.toast("Started %s" % recipe.display_name)
	return true

func collect_output() -> bool:
	if _operation_busy:
		return false
	_operation_busy = true
	var result := _collect_output_internal()
	_operation_busy = false
	return result

func _collect_output_internal() -> bool:
	_update_job()
	if not output_ready or active_recipe_id == &"":
		return false
	var item := ContentDB.get_item(pending_output_item_id)
	if item == null or pending_output_quantity <= 0:
		# The promised output vanished in a content update. Restore the snapshotted
		# inputs atomically before unlocking the station. Unknown legacy inputs are
		# preserved by InventoryStore as non-blocking legacy entries.
		if pending_input_refund.is_empty():
			_clear_job()
			GameEvents.toast("Unavailable legacy processing job was cleared")
			return false
		if not InventoryState.apply_refund_snapshot_atomic(pending_input_refund):
			GameEvents.toast("Make room for the refunded processing materials")
			return false
		_clear_job()
		GameEvents.toast("Processing content changed · materials refunded")
		return false
	if not InventoryState.can_add_item(item, pending_output_quantity):
		GameEvents.toast("Make room for the full output")
		return false
	if InventoryState.add_item(item, pending_output_quantity) > 0:
		return false
	var collected_recipe_id := active_recipe_id
	var collected_id := item.id
	var collected_quantity := pending_output_quantity
	_clear_job()
	output_collected.emit(station_id, collected_id, collected_quantity)
	GameEvents.item_processed.emit(collected_recipe_id, collected_id, collected_quantity)
	GameEvents.toast("Collected %s x%d" % [item.display_name, collected_quantity])
	return true

func get_minutes_remaining() -> int:
	if active_recipe_id == &"" or output_ready:
		return 0
	return maxi(finish_at - _absolute_minute(WorldClock.day, WorldClock.minute_of_day), 0)

func get_state_data() -> Dictionary:
	return {
		"recipe_id": String(active_recipe_id),
		"finish_at": finish_at,
		"output_ready": output_ready,
		"output_item_id": String(pending_output_item_id),
		"output_quantity": pending_output_quantity,
		"input_refund": pending_input_refund.duplicate(true),
	}

func load_state_data(data: Dictionary, persist := true) -> void:
	active_recipe_id = _safe_string_name(data.get("recipe_id", ""))
	finish_at = _safe_nonnegative_int(data.get("finish_at", 0))
	var raw_ready: Variant = data.get("output_ready", false)
	output_ready = raw_ready is bool and bool(raw_ready)
	pending_output_item_id = _safe_string_name(data.get("output_item_id", ""))
	pending_output_quantity = _safe_nonnegative_int(data.get("output_quantity", 0))
	var refund_raw: Variant = data.get("input_refund", {})
	pending_input_refund = _sanitize_refund_snapshot(refund_raw)
	var normalized := false
	if active_recipe_id == &"":
		finish_at = 0
		output_ready = false
		if pending_output_item_id != &"" or pending_output_quantity > 0 or not pending_input_refund.is_empty():
			pending_output_item_id = &""
			pending_output_quantity = 0
			pending_input_refund.clear()
			normalized = true
	else:
		var recipe := _get_recipe(active_recipe_id)
		if (pending_output_item_id == &"" or pending_output_quantity <= 0) and recipe != null:
			# Backfill promised output for pre-snapshot saves while the recipe still
			# exists in this station's current recipe list.
			pending_output_item_id = recipe.output_item_id
			pending_output_quantity = recipe.output_quantity
			normalized = true
		if pending_input_refund.is_empty() and recipe != null:
			pending_input_refund = _build_input_refund_snapshot(recipe.inputs)
			normalized = true
		if pending_output_item_id == &"" or pending_output_quantity <= 0:
			# Ancient orphan: no recipe and no promised output can be inferred. There
			# is no deterministic value to restore, so unlock instead of hard-locking.
			active_recipe_id = &""
			finish_at = 0
			output_ready = false
			pending_output_item_id = &""
			pending_output_quantity = 0
			pending_input_refund.clear()
			normalized = true
	if persist or normalized:
		_persist()
	_update_job()
	_refresh()

func _on_interacted(_actor: Node) -> void:
	_update_job()
	if output_ready:
		collect_output()
		return
	if active_recipe_id != &"":
		GameEvents.toast("%s · %d min remaining" % [display_name, get_minutes_remaining()])
		return
	for recipe_id: StringName in recipe_ids:
		var recipe := _get_recipe(recipe_id)
		if recipe != null and recipe.can_start() and start_recipe(recipe.id):
			return
	GameEvents.toast("No processable materials")

func _on_time_changed(_day: int, _minute_of_day: int) -> void:
	_update_job()

func _update_job() -> void:
	if active_recipe_id == &"" or output_ready:
		_refresh()
		return
	if _absolute_minute(WorldClock.day, WorldClock.minute_of_day) < finish_at:
		_refresh()
		return
	output_ready = true
	_persist()
	_refresh()
	job_finished.emit(station_id, active_recipe_id)
	var recipe := _get_recipe(active_recipe_id)
	if recipe != null:
		GameEvents.toast("%s finished %s" % [display_name, recipe.display_name])

func _get_recipe(recipe_id: StringName) -> ProcessingRecipeData:
	if not recipe_ids.has(recipe_id):
		return null
	return ContentDB.get_processing_recipe(recipe_id)

func _build_input_refund_snapshot(inputs: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for raw_id: Variant in inputs.keys():
		var item_id := StringName(String(raw_id))
		var quantity := maxi(int(inputs[raw_id]), 0)
		if item_id == &"" or quantity <= 0:
			continue
		var item := ContentDB.get_item(item_id)
		snapshot[String(item_id)] = {
			"quantity": quantity,
			"display_name": item.display_name if item != null else String(item_id),
			"max_stack": item.max_stack if item != null else 99,
		}
	return snapshot

func _clear_job() -> void:
	active_recipe_id = &""
	finish_at = 0
	output_ready = false
	pending_output_item_id = &""
	pending_output_quantity = 0
	pending_input_refund.clear()
	_persist()
	_refresh()

func _refresh() -> void:
	if interactable == null or state_label == null:
		return
	if output_ready:
		interactable.prompt_text = "Collect output"
		state_label.text = "%s · Ready" % display_name
		if body_visual != null:
			body_visual.modulate = Color(1.0, 0.82, 0.48, 1.0)
	elif active_recipe_id != &"":
		interactable.prompt_text = "Check %s" % display_name
		state_label.text = "%s · %d min" % [display_name, get_minutes_remaining()]
		if body_visual != null:
			body_visual.modulate = Color(1.0, 0.58, 0.32, 1.0)
	else:
		interactable.prompt_text = "Use %s" % display_name
		state_label.text = display_name
		if body_visual != null:
			body_visual.modulate = Color.WHITE

func _persist() -> void:
	if station_id == &"":
		return
	WorldState.set_value(_state_key(), get_state_data())

func _load_state() -> void:
	if station_id == &"":
		return
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if raw is Dictionary and not raw.is_empty():
		load_state_data(raw, false)

func _state_key() -> StringName:
	return StringName("processing:%s" % String(station_id))

func _sanitize_refund_snapshot(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return {}
	var normalized: Dictionary = {}
	for raw_id: Variant in (snapshot as Dictionary).keys():
		var item_id := StringName(String(raw_id))
		if item_id == &"":
			continue
		var raw_entry: Variant = (snapshot as Dictionary)[raw_id]
		var quantity := 0
		var display_name := String(item_id)
		var max_stack := 99
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			quantity = _safe_nonnegative_int(entry.get("quantity", 0))
			var raw_name: Variant = entry.get("display_name", display_name)
			if raw_name is String or raw_name is StringName:
				display_name = String(raw_name)
			var raw_stack: Variant = entry.get("max_stack", 99)
			if typeof(raw_stack) == TYPE_INT or typeof(raw_stack) == TYPE_FLOAT:
				max_stack = maxi(int(raw_stack), 1)
		else:
			quantity = _safe_nonnegative_int(raw_entry)
		if quantity <= 0:
			continue
		normalized[String(item_id)] = {
			"quantity": quantity,
			"display_name": display_name,
			"max_stack": max_stack,
		}
	return normalized

func _safe_nonnegative_int(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	return maxi(int(value), 0)

func _safe_string_name(value: Variant) -> StringName:
	if value is String or value is StringName:
		return StringName(String(value))
	return &""

func _absolute_minute(day: int, minute_of_day: int) -> int:
	return (maxi(day, 1) - 1) * 1440 + clampi(minute_of_day, 0, 1439)
