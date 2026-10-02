class_name FarmToolController
extends Area2D

@export var action: StringName = &"use_tool"

const SUPPORTED_TOOL_ACTIONS: Array[StringName] = [&"hoe", &"water", &"pickaxe"]

var _action_busy := false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(action):
		return
	var selected := PlayerState.get_selected_item()
	if selected == null:
		return
	if selected.is_edible():
		var target := get_nearest_tool_target()
		if target == null:
			_consume_food(selected)
			get_viewport().set_input_as_handled()
		return
	if selected.is_placeable():
		_place_selected(selected)
		get_viewport().set_input_as_handled()
		return
	var owns_action := selected.is_seed() or (selected.is_tool() and SUPPORTED_TOOL_ACTIONS.has(selected.tool_action))
	if not owns_action:
		return
	if selected.kind == ItemData.Kind.TOOL and not InventoryState.has_item(selected.id):
		GameEvents.toast("You do not have %s" % selected.display_name)
		get_viewport().set_input_as_handled()
		return
	var target := get_nearest_tool_target()
	if target == null:
		GameEvents.toast("Nothing to use %s on" % selected.display_name)
		get_viewport().set_input_as_handled()
		return
	var used := false
	if target is FarmPlot and selected.is_tool() and (selected.tool_action == &"hoe" or selected.tool_action == &"water") and selected.tool_power > 1:
		used = _use_multi_plot_tool(selected, target as FarmPlot)
	else:
		used = bool(target.call("use_item", selected.id))
	if used:
		_play_use_animation()
		GameEvents.item_used.emit(selected.id)
	get_viewport().set_input_as_handled()

func get_nearest_tool_target() -> Node2D:
	var nearest: Node2D = null
	var best_distance := INF
	for area: Area2D in get_overlapping_areas():
		if not area.has_method("use_item"):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = area
	return nearest

func get_nearest_plot() -> FarmPlot:
	return get_nearest_tool_target() as FarmPlot

func _use_multi_plot_tool(tool: ItemData, target: FarmPlot) -> bool:
	if _action_busy:
		return false
	_action_busy = true
	var result := _use_multi_plot_tool_internal(tool, target)
	_action_busy = false
	return result

func _use_multi_plot_tool_internal(tool: ItemData, target: FarmPlot) -> bool:
	if tool == null or target == null:
		return false
	var field := target.get_parent() as FarmField
	if field == null:
		return target.use_item(tool.id)
	var candidates: Array[FarmPlot] = []
	var step := maxf(absf(field.cell_spacing.x), absf(field.cell_spacing.y))
	var radius := maxf(step * float(maxi(tool.tool_power - 1, 1)) * 1.45, 1.0)
	for plot: FarmPlot in field.get_all_plots():
		if plot == null or not plot.can_apply_tool_action(tool.tool_action):
			continue
		if plot.global_position.distance_to(target.global_position) <= radius:
			candidates.append(plot)
	candidates.sort_custom(func(a: FarmPlot, b: FarmPlot) -> bool:
		return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position)
	)
	if candidates.is_empty():
		return target.use_item(tool.id)
	var energy_cost := target.get_tool_energy_cost(tool)
	if energy_cost > 0 and not PlayerState.consume_energy(energy_cost):
		GameEvents.toast("Not enough energy")
		return false
	var affected := 0
	for plot: FarmPlot in candidates:
		if affected >= maxi(tool.tool_power, 1):
			break
		if plot.use_item(tool.id, false, false):
			affected += 1
	if affected <= 0:
		if energy_cost > 0:
			PlayerState.restore_energy(energy_cost)
		return false
	var verb := "Tilled" if tool.tool_action == &"hoe" else "Watered"
	GameEvents.toast("%s %d plots" % [verb, affected])
	return true

func _consume_food(item: ItemData) -> void:
	if _action_busy:
		return
	_action_busy = true
	_consume_food_internal(item)
	_action_busy = false

func _consume_food_internal(item: ItemData) -> void:
	if item == null or not item.is_edible() or not InventoryState.has_item(item.id):
		GameEvents.toast("No %s available" % (item.display_name if item != null else "food"))
		return
	var can_restore_energy := item.energy_restore > 0 and PlayerState.energy < PlayerState.max_energy
	var can_restore_health := item.health_restore > 0 and PlayerState.health < PlayerState.max_health
	var has_buff := item.food_buff_id != &""
	if not can_restore_energy and not can_restore_health and not has_buff:
		GameEvents.toast("You do not need that right now")
		return
	if not InventoryState.remove_item(item.id, 1):
		return
	if item.energy_restore > 0:
		PlayerState.restore_energy(item.energy_restore)
	if item.health_restore > 0:
		PlayerState.heal(item.health_restore)
	if has_buff:
		BuffState.apply_buff(item.food_buff_id)
	GameEvents.item_used.emit(item.id)
	var parts := PackedStringArray()
	if item.energy_restore > 0:
		parts.append("+%d energy" % item.energy_restore)
	if item.health_restore > 0:
		parts.append("+%d HP" % item.health_restore)
	GameEvents.toast("Ate %s%s" % [item.display_name, " (" + ", ".join(parts) + ")" if not parts.is_empty() else ""])

func _place_selected(item: ItemData) -> void:
	if _action_busy:
		return
	_action_busy = true
	_place_selected_internal(item)
	_action_busy = false

func _place_selected_internal(item: ItemData) -> void:
	if item == null or not item.is_placeable() or not InventoryState.has_item(item.id, 1):
		return
	var location := ContentDB.get_current_location(get_tree())
	if location == null:
		GameEvents.toast("You cannot build here")
		return
	var data := ContentDB.get_placeable(item.placeable_id)
	if data == null or not data.is_allowed_in(location):
		GameEvents.toast("%s cannot be placed here" % item.display_name)
		return
	var record := BuildingState.place_from_inventory(item.placeable_id, location.id, global_position)
	if record.is_empty():
		GameEvents.toast("Not enough space to place %s" % item.display_name)
		return
	_play_use_animation()
	GameEvents.item_used.emit(item.id)
	GameEvents.toast("Placed %s" % item.display_name)

func _play_use_animation() -> void:
	var actor := get_parent()
	if actor == null:
		return
	var visual := actor.get_node_or_null("ActorVisual") as DirectionalActorVisual
	if visual != null:
		visual.play_action(&"attack")
