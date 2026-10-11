class_name FarmPlot
extends Interactable

signal farm_state_changed

@export var persistent_id: StringName
@export var location_id: StringName
@export_range(1, 100, 1) var hoe_energy_cost := 4
@export_range(1, 100, 1) var water_energy_cost := 2
@export_range(0, 100, 1) var plant_energy_cost := 1

@onready var soil_visual: Polygon2D = $Soil
@onready var crop_visual: Polygon2D = $Crop
@onready var state_label: Label = $StateLabel

var tilled := false
var watered := false
var crop_id: StringName
var growth_days := 0
var last_processed_day := 0
var _interaction_busy := false

func _ready() -> void:
	WorldClock.day_changed.connect(_on_day_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_load_state()
	if last_processed_day <= 0:
		last_processed_day = WorldClock.day
	elif last_processed_day < WorldClock.day:
		_advance_to_day(WorldClock.day)
	if tilled and _is_watered_by_environment(WorldClock.day):
		watered = true
		_persist()
	_refresh_visual()

func use_item(item_id: StringName, consume_energy: bool = true, show_message: bool = true) -> bool:
	if _interaction_busy:
		return false
	_interaction_busy = true
	var result := _use_item_internal(item_id, consume_energy, show_message)
	_interaction_busy = false
	return result

func _use_item_internal(item_id: StringName, consume_energy: bool, show_message: bool) -> bool:
	var item := ItemCatalog.get_item(item_id)
	if item == null:
		if show_message:
			GameEvents.toast("Nothing selected")
		return false
	if item.is_tool():
		match item.tool_action:
			&"hoe":
				return _till(item, consume_energy, show_message)
			&"water":
				return _water(item, consume_energy, show_message)
	if item.is_seed():
		return _plant(item)
	if show_message:
		GameEvents.toastf("%s cannot be used on soil", [item.display_name])
	return false

func can_apply_tool_action(tool_action: StringName) -> bool:
	match tool_action:
		&"hoe":
			return not tilled
		&"water":
			return tilled and not watered
		_:
			return false

func get_tool_energy_cost(tool: ItemData) -> int:
	if tool == null:
		return 0
	match tool.tool_action:
		&"hoe":
			return _scaled_tool_energy(hoe_energy_cost, tool)
		&"water":
			return _scaled_tool_energy(water_energy_cost, tool)
		_:
			return 0

func interact(actor: Node) -> void:
	if can_harvest():
		if _interaction_busy:
			return
		_interaction_busy = true
		_harvest()
		_interaction_busy = false
		return
	super.interact(actor)

func can_harvest() -> bool:
	var crop := CropCatalog.get_crop(crop_id)
	return crop != null and growth_days >= crop.days_to_mature

func get_growth_progress() -> float:
	var crop := CropCatalog.get_crop(crop_id)
	if crop == null:
		return 0.0
	return clampf(float(growth_days) / float(maxi(crop.days_to_mature, 1)), 0.0, 1.0)

func get_state_data() -> Dictionary:
	return {
		"tilled": tilled,
		"watered": watered,
		"crop_id": String(crop_id),
		"growth_days": growth_days,
		"last_processed_day": last_processed_day,
	}

func load_state_data(data: Dictionary, persist := true) -> void:
	var raw_tilled: Variant = data.get("tilled", false)
	var raw_watered: Variant = data.get("watered", false)
	tilled = raw_tilled is bool and bool(raw_tilled)
	watered = raw_watered is bool and bool(raw_watered)
	crop_id = StringName(String(data.get("crop_id", "")))
	growth_days = maxi(_safe_int(data.get("growth_days", 0), 0), 0)
	last_processed_day = clampi(_safe_int(data.get("last_processed_day", WorldClock.day), WorldClock.day), 1, maxi(WorldClock.day, 1))
	# A crop definition can disappear across content versions. Preserve the raw
	# WorldState until the player next changes this plot, but do not let an
	# invisible orphan crop permanently block planting in the current session.
	var crop := CropCatalog.get_crop(crop_id)
	if crop_id != &"" and crop == null:
		crop_id = &""
		growth_days = 0
	elif crop != null:
		growth_days = mini(growth_days, crop.days_to_mature)
	if persist:
		_persist()
	_refresh_visual()

func _till(tool: ItemData, consume_energy: bool = true, show_message: bool = true) -> bool:
	if tilled:
		if show_message:
			GameEvents.toast("This soil is already tilled")
		return false
	var energy_cost := _scaled_tool_energy(hoe_energy_cost, tool)
	if consume_energy and not PlayerState.consume_energy(energy_cost):
		if show_message:
			GameEvents.toast("Not enough energy")
		return false
	tilled = true
	last_processed_day = WorldClock.day
	watered = _is_watered_by_environment(WorldClock.day)
	_commit(tr("Soil tilled"), show_message)
	return true

func _water(tool: ItemData, consume_energy: bool = true, show_message: bool = true) -> bool:
	if not tilled:
		if show_message:
			GameEvents.toast("Till the soil first")
		return false
	if watered:
		if show_message:
			GameEvents.toast("The soil is already watered")
		return false
	var energy_cost := _scaled_tool_energy(water_energy_cost, tool)
	if consume_energy and not PlayerState.consume_energy(energy_cost):
		if show_message:
			GameEvents.toast("Not enough energy")
		return false
	watered = true
	_commit(tr("Soil watered"), show_message)
	return true

func _plant(seed: ItemData) -> bool:
	if not tilled:
		GameEvents.toast("Till the soil before planting")
		return false
	if crop_id != &"":
		GameEvents.toast("Something is already growing here")
		return false
	var crop := CropCatalog.get_crop(seed.crop_id)
	if crop == null:
		return false
	if not crop.can_grow_in(WorldClock.get_season_name()):
		GameEvents.toastf("%s cannot grow in %s", [crop.display_name, WorldClock.get_season_name()])
		return false
	if not InventoryState.has_item(seed.id, 1):
		GameEvents.toastf("No %s left", [seed.display_name])
		return false
	if plant_energy_cost > 0 and not PlayerState.consume_energy(plant_energy_cost):
		GameEvents.toast("Not enough energy")
		return false
	InventoryState.remove_item(seed.id, 1)
	crop_id = crop.id
	growth_days = 0
	_commit(tr("Planted %s") % tr(crop.display_name))
	return true

func _harvest() -> void:
	var crop := CropCatalog.get_crop(crop_id)
	if crop == null:
		return
	var item := ItemCatalog.get_item(crop.harvest_item_id)
	if item == null:
		return
	if not InventoryState.can_add_item(item, crop.harvest_quantity):
		GameEvents.toast("Make room for the full harvest")
		return
	if InventoryState.add_item(item, crop.harvest_quantity) > 0:
		return
	var collected := crop.harvest_quantity
	GameEvents.crop_harvested.emit(crop.id, crop.harvest_item_id, collected)
	if crop.regrow_days > 0:
		growth_days = maxi(crop.days_to_mature - crop.regrow_days, 0)
	else:
		crop_id = &""
		growth_days = 0
	_commit(tr("Harvested %s") % tr(crop.display_name))

func _on_day_changed(day: int) -> void:
	_advance_to_day(day)

func _advance_to_day(target_day: int) -> void:
	var resolved_target := maxi(target_day, 1)
	if last_processed_day <= 0:
		last_processed_day = resolved_target
	# Empty plots have no per-day crop state to simulate. Jump directly to the
	# target day and derive only today's environmental watering, so a corrupt or
	# debug save with a huge day value cannot force millions of no-op iterations.
	if crop_id == &"":
		last_processed_day = resolved_target
		watered = tilled and _is_watered_by_environment(resolved_target)
		_persist()
		_refresh_visual()
		farm_state_changed.emit()
		return
	while last_processed_day < resolved_target:
		var next_day := last_processed_day + 1
		_process_day_transition(next_day)
		last_processed_day = next_day
		if crop_id == &"" and last_processed_day < resolved_target:
			# Once a seasonal crop has died there is no remaining per-day crop state.
			# Jump the empty plot to the destination and derive only today's water.
			last_processed_day = resolved_target
			watered = tilled and _is_watered_by_environment(resolved_target)
			break
	_persist()
	_refresh_visual()
	farm_state_changed.emit()

func _process_day_transition(day: int) -> void:
	var crop := CropCatalog.get_crop(crop_id)
	if crop != null:
		var previous_season := GameClock.get_season_name_for_day(maxi(day - 1, 1))
		if watered and crop.can_grow_in(previous_season):
			growth_days = mini(growth_days + 1, crop.days_to_mature)
		var next_season := GameClock.get_season_name_for_day(day)
		if not crop.can_grow_in(next_season):
			# Immature crops fail immediately on the season boundary. A crop that
			# finishes maturing from the previous valid day gets one grace day to be
			# harvested, but it must not remain frozen and harvestable indefinitely.
			var spent_previous_day_out_of_season := not crop.can_grow_in(previous_season)
			if growth_days < crop.days_to_mature or spent_previous_day_out_of_season:
				crop_id = &""
				growth_days = 0
	watered = tilled and _is_watered_by_environment(day)

func _is_watered_by_environment(day: int) -> bool:
	if WeatherState.is_raining(day):
		return true
	var resolved_location := location_id
	if resolved_location == &"":
		var location := ContentDB.get_current_location(get_tree())
		if location != null:
			resolved_location = location.id
	if resolved_location == &"":
		return false
	return BuildingState.is_point_affected(resolved_location, &"water", global_position)

func _commit(message: String, show_message: bool = true) -> void:
	_persist()
	_refresh_visual()
	farm_state_changed.emit()
	if show_message:
		GameEvents.toast(message)

func _persist() -> void:
	if persistent_id == &"":
		return
	WorldState.set_value(_state_key(), get_state_data())

func _load_state() -> void:
	if persistent_id == &"":
		return
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if raw is Dictionary:
		load_state_data(raw, false)

func _state_key() -> StringName:
	return StringName("farm:%s" % String(persistent_id))

func _scaled_tool_energy(base_cost: int, tool: ItemData) -> int:
	var power := maxi(tool.tool_power if tool != null else 1, 1)
	var reduced := float(maxi(base_cost, 1)) / float(power)
	var multiplier := BuffState.get_multiplier(&"tool_energy") * Skills.get_energy_multiplier(SkillManager.FARMING)
	return maxi(int(floor(reduced * multiplier)), 1)

func _refresh_visual() -> void:
	if soil_visual == null or crop_visual == null or state_label == null:
		return
	if not tilled:
		soil_visual.color = Color(0.27, 0.22, 0.16, 1)
	elif watered:
		soil_visual.color = Color(0.20, 0.19, 0.16, 1)
	else:
		soil_visual.color = Color(0.42, 0.30, 0.19, 1)
	var crop := CropCatalog.get_crop(crop_id)
	crop_visual.visible = crop != null
	if crop != null:
		var progress := get_growth_progress()
		var half_height := lerpf(2.0, 10.0, progress)
		crop_visual.polygon = PackedVector2Array([
			Vector2(-6, 7),
			Vector2(6, 7),
			Vector2(5, 7 - half_height * 2.0),
			Vector2(-5, 7 - half_height * 2.0),
		])
		crop_visual.color = crop.sprout_color.lerp(crop.mature_color, progress)
		state_label.text = "%s %d/%d" % [tr(crop.display_name), growth_days, crop.days_to_mature]
	else:
		state_label.text = tr("Tilled") if tilled else tr("Soil")
	enabled = can_harvest()
	if enabled and crop != null:
		set_prompt("Harvest %s", [crop.display_name])
	else:
		set_prompt("Farm plot")

func _on_locale_changed(_locale: String) -> void:
	_refresh_visual()

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
