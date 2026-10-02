class_name TownProjectService
extends Node

signal project_changed(project_id: StringName, state: Dictionary)
signal project_completed(project_id: StringName)
signal project_claimed(project_id: StringName)

const STATE_KEY := &"town_projects:state"

var _contributing_projects: Dictionary = {}
var _claiming_projects: Dictionary = {}

func get_project(project_id: StringName) -> TownProjectData:
	return ContentDB.get_town_project(project_id)

func get_projects_for_location(location_id: StringName) -> Array[TownProjectData]:
	var result: Array[TownProjectData] = []
	for project: TownProjectData in ContentDB.get_all_town_projects():
		if project != null and (location_id == &"" or project.location_id == location_id):
			result.append(project)
	return result

func get_state(project_id: StringName) -> Dictionary:
	var all_state := _get_all_state()
	var raw: Variant = all_state.get(String(project_id), {})
	if not raw is Dictionary:
		return {}
	var source: Dictionary = raw
	var state: Dictionary = source.duplicate(true)
	var normalized_progress: Dictionary = {}
	var raw_progress: Variant = source.get("progress", {})
	if raw_progress is Dictionary:
		for raw_id: Variant in (raw_progress as Dictionary).keys():
			var quantity := _safe_nonnegative_int((raw_progress as Dictionary)[raw_id])
			if quantity > 0:
				normalized_progress[String(raw_id)] = quantity
	state["progress"] = normalized_progress
	var claimed := source.get("claimed", false) is bool and bool(source.get("claimed", false))
	var completed := claimed or (source.get("completed", false) is bool and bool(source.get("completed", false)))
	state["completed"] = completed
	state["claimed"] = claimed
	state["completed_day"] = _safe_nonnegative_int(source.get("completed_day", 0))
	state["claimed_day"] = _safe_nonnegative_int(source.get("claimed_day", 0))
	return state

func get_progress(project_id: StringName, item_id: StringName) -> int:
	var state := get_state(project_id)
	var progress: Variant = state.get("progress", {})
	if not progress is Dictionary:
		return 0
	return int((progress as Dictionary).get(String(item_id), 0))

func is_completed(project_id: StringName) -> bool:
	return bool(get_state(project_id).get("completed", false))

func is_claimed(project_id: StringName) -> bool:
	return bool(get_state(project_id).get("claimed", false))

func is_available(project_id: StringName) -> bool:
	var project := get_project(project_id)
	if project == null:
		return false
	for prerequisite_id: StringName in project.prerequisites:
		if not is_completed(prerequisite_id):
			return false
	return true

func contribute(project_id: StringName, item_id: StringName, quantity: int = 999999) -> int:
	var project_key := String(project_id)
	if _contributing_projects.has(project_key):
		return 0
	var project := get_project(project_id)
	if project == null or not is_available(project_id) or is_completed(project_id):
		return 0
	var required := project.get_required_quantity(item_id)
	if required <= 0:
		return 0
	var already := get_progress(project_id, item_id)
	var remaining := maxi(required - already, 0)
	var donated := mini(maxi(quantity, 0), mini(remaining, InventoryState.get_quantity(item_id)))
	if donated <= 0:
		return 0
	_contributing_projects[project_key] = true
	if not InventoryState.remove_item(item_id, donated):
		_contributing_projects.erase(project_key)
		return 0
	var state := _ensure_state(project_id)
	var progress: Dictionary = state.get("progress", {}) if state.get("progress", {}) is Dictionary else {}
	progress[String(item_id)] = already + donated
	state["progress"] = progress
	if _requirements_complete(project, progress):
		state["completed"] = true
		state["completed_day"] = WorldClock.day
		state["reward_snapshot"] = DeferredRewardSnapshot.ensure(state.get("reward_snapshot", {}), project.reward_items, project.reward_money)
	_set_state(project_id, state)
	if bool(state.get("completed", false)):
		_apply_unlock_flags(project)
	_contributing_projects.erase(project_key)
	if bool(state.get("completed", false)):
		project_completed.emit(project_id)
		GameEvents.toast("Project complete: %s" % project.display_name)
	else:
		GameEvents.toast("Donated %d %s" % [donated, _item_name(item_id)])
	return donated

func contribute_all_available(project_id: StringName) -> int:
	var project := get_project(project_id)
	if project == null or not is_available(project_id) or is_completed(project_id):
		return 0
	var total := 0
	var ids: Array[String] = []
	for raw_id: Variant in project.requirements.keys():
		ids.append(String(raw_id))
	ids.sort()
	for raw_id: String in ids:
		total += contribute(project_id, StringName(raw_id))
		if is_completed(project_id):
			break
	return total

func reconcile_loaded_progress() -> Array[StringName]:
	var completed_now: Array[StringName] = []
	for project: TownProjectData in ContentDB.get_all_town_projects():
		if project == null:
			continue
		var state := get_state(project.id)
		if state.is_empty():
			continue
		var progress: Dictionary = state.get("progress", {}) if state.get("progress", {}) is Dictionary else {}
		var was_completed := bool(state.get("completed", false))
		var claimed := bool(state.get("claimed", false))
		if not was_completed and not claimed and not _requirements_complete(project, progress):
			continue
		var changed := false
		if not was_completed:
			state["completed"] = true
			completed_now.append(project.id)
			changed = true
		var completed_day := clampi(int(state.get("completed_day", 0)), 0, WorldClock.day)
		if completed_day <= 0:
			completed_day = WorldClock.day
		if int(state.get("completed_day", 0)) != completed_day:
			state["completed_day"] = completed_day
			changed = true
		if claimed:
			var claimed_day := clampi(int(state.get("claimed_day", 0)), 0, WorldClock.day)
			if claimed_day <= 0:
				claimed_day = completed_day
			if int(state.get("claimed_day", 0)) != claimed_day:
				state["claimed_day"] = claimed_day
				changed = true
		if not claimed:
			var reward := DeferredRewardSnapshot.ensure(state.get("reward_snapshot", {}), project.reward_items, project.reward_money)
			var raw_reward: Variant = state.get("reward_snapshot", {})
			if not raw_reward is Dictionary or (raw_reward as Dictionary).is_empty():
				state["reward_snapshot"] = reward
				changed = true
		if changed:
			_set_state(project.id, state)
		_apply_unlock_flags(project)
	return completed_now

func claim_reward(project_id: StringName) -> bool:
	var claim_key := String(project_id)
	if _claiming_projects.has(claim_key):
		return false
	var project := get_project(project_id)
	if project == null or not is_completed(project_id) or is_claimed(project_id):
		return false
	_claiming_projects[claim_key] = true
	var state := _ensure_state(project_id)
	var reward := DeferredRewardSnapshot.ensure(state.get("reward_snapshot", {}), project.reward_items, project.reward_money)
	var raw_reward: Variant = state.get("reward_snapshot", {})
	if not raw_reward is Dictionary or (raw_reward as Dictionary).is_empty():
		state["reward_snapshot"] = reward.duplicate(true)
		_set_state(project_id, state)
	if not DeferredRewardSnapshot.grant_items(reward):
		_claiming_projects.erase(claim_key)
		GameEvents.toast("Make room in your inventory before claiming the project reward")
		return false
	var reward_items: Variant = reward.get("items", {})
	if reward_items is Dictionary:
		for raw_id: Variant in (reward_items as Dictionary).keys():
			var item_id := StringName(String(raw_id))
			var item := ContentDB.get_item(item_id)
			if item != null and item.is_placeable():
				PlayerState.ensure_hotbar_item(item_id)
	var reward_money := DeferredRewardSnapshot.get_money(reward)
	if reward_money > 0:
		PlayerState.add_money(reward_money)
	state["claimed"] = true
	state["claimed_day"] = WorldClock.day
	_set_state(project_id, state)
	project_claimed.emit(project_id)
	_claiming_projects.erase(claim_key)
	GameEvents.toast("Project reward claimed: %s" % project.display_name)
	return true

func get_project_summary(project_id: StringName) -> String:
	var project := get_project(project_id)
	if project == null:
		return "Unknown project"
	if not is_available(project_id):
		return "%s · Locked" % project.display_name
	if is_claimed(project_id):
		return "%s · Complete" % project.display_name
	if is_completed(project_id):
		return "%s · Reward ready" % project.display_name
	var done := 0
	var total := 0
	for raw_id: Variant in project.requirements.keys():
		var item_id := StringName(String(raw_id))
		var required := project.get_required_quantity(item_id)
		total += required
		done += mini(get_progress(project_id, item_id), required)
	return "%s · %d/%d donated" % [project.display_name, done, total]

func get_location_summary(location_id: StringName) -> String:
	var parts := PackedStringArray()
	for project: TownProjectData in get_projects_for_location(location_id):
		parts.append(get_project_summary(project.id))
	return " · ".join(parts)

func _ensure_state(project_id: StringName) -> Dictionary:
	var state := get_state(project_id)
	if state.is_empty():
		state = {
			"progress": {},
			"completed": false,
			"claimed": false,
			"completed_day": 0,
			"claimed_day": 0,
		}
	return state

func _requirements_complete(project: TownProjectData, progress: Dictionary) -> bool:
	for raw_id: Variant in project.requirements.keys():
		var required := project.get_required_quantity(StringName(String(raw_id)))
		if required <= 0 or _safe_nonnegative_int(progress.get(String(raw_id), 0)) < required:
			return false
	return not project.requirements.is_empty()

func _apply_unlock_flags(project: TownProjectData) -> void:
	if project == null:
		return
	for flag: StringName in project.unlock_flags:
		if flag != &"" and not WorldState.get_bool(flag):
			WorldState.set_value(flag, true)

func _safe_nonnegative_int(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	return maxi(int(value), 0)

func _item_name(item_id: StringName) -> String:
	var item := ContentDB.get_item(item_id)
	return item.display_name if item != null else String(item_id).capitalize()

func _get_all_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(STATE_KEY, {})
	return raw.duplicate(true) if raw is Dictionary else {}

func _set_state(project_id: StringName, state: Dictionary) -> void:
	var all_state := _get_all_state()
	all_state[String(project_id)] = state.duplicate(true)
	WorldState.set_value(STATE_KEY, all_state)
	project_changed.emit(project_id, state.duplicate(true))
