class_name TownProjectService
extends Node

## The town's community projects (`TownProjectData`): the player donates the
## items a project asks for from the inventory, and once every item is in, the
## project is complete and its reward (items and money) can be claimed. A project
## opens once the projects it requires are complete.
##
## The reward is fixed when the project completes, and claiming it is refused
## while the items do not fit in the inventory. Progress lives in `WorldState`
## (`town_projects:state`), so it is saved with the world, and NPCs know it
## through `NpcContext`. `project_changed`, `project_completed` and
## `project_claimed` announce each step.

signal project_changed(town_project_id: StringName, state: Dictionary)
signal project_completed(town_project_id: StringName)
signal project_claimed(town_project_id: StringName)

const STATE_KEY := &"town_projects:state"

var _contributing_projects: Dictionary = {}
var _claiming_projects: Dictionary = {}

func get_project(project_id: StringName) -> TownProjectData:
	return TownProjectData.find(project_id)

func get_projects_for_location(location_id: StringName) -> Array[TownProjectData]:
	var result: Array[TownProjectData] = []
	for project: TownProjectData in TownProjectData.find_all():
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
			var quantity := SaveValues.count((raw_progress as Dictionary)[raw_id])
			if quantity > 0:
				normalized_progress[String(raw_id)] = quantity
	state["progress"] = normalized_progress
	var claimed := source.get("claimed", false) is bool and bool(source.get("claimed", false))
	var completed := claimed or (source.get("completed", false) is bool and bool(source.get("completed", false)))
	state["completed"] = completed
	state["claimed"] = claimed
	state["completed_day"] = SaveValues.count(source.get("completed_day", 0))
	state["claimed_day"] = SaveValues.count(source.get("claimed_day", 0))
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
	_contributing_projects.erase(project_key)
	if bool(state.get("completed", false)):
		project_completed.emit(project_id)
		GameEvents.toastf("Project complete: %s", [project.display_name])
	else:
		GameEvents.toastf("Donated %d %s", [donated, _item_name(item_id)])
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
	if not DeferredRewardSnapshot.grant_items(reward):
		_claiming_projects.erase(claim_key)
		GameEvents.toast("Make room in your inventory before claiming the project reward")
		return false
	var reward_items: Variant = reward.get("items", {})
	if reward_items is Dictionary:
		for raw_id: Variant in (reward_items as Dictionary).keys():
			var item_id := StringName(String(raw_id))
			var item := ItemData.find(item_id)
			if item != null and item.is_placeable():
				Hotbar.ensure_item(item_id)
	var reward_money := DeferredRewardSnapshot.get_money(reward)
	if reward_money > 0:
		PlayerState.add_money(reward_money)
	state["claimed"] = true
	state["claimed_day"] = WorldClock.day
	_set_state(project_id, state)
	project_claimed.emit(project_id)
	_claiming_projects.erase(claim_key)
	GameEvents.toastf("Project reward claimed: %s", [project.display_name])
	return true

func get_project_summary(project_id: StringName) -> String:
	var project := get_project(project_id)
	if project == null:
		return tr("Unknown project")
	if not is_available(project_id):
		return tr("%s · Locked") % tr(project.display_name)
	if is_claimed(project_id):
		return tr("%s · Complete") % tr(project.display_name)
	if is_completed(project_id):
		return tr("%s · Reward ready") % tr(project.display_name)
	var done := 0
	var total := 0
	for raw_id: Variant in project.requirements.keys():
		var item_id := StringName(String(raw_id))
		var required := project.get_required_quantity(item_id)
		total += required
		done += mini(get_progress(project_id, item_id), required)
	return tr("%s · %d/%d donated") % [tr(project.display_name), done, total]

func get_location_summary(location_id: StringName) -> String:
	var parts := PackedStringArray()
	for project: TownProjectData in get_projects_for_location(location_id):
		parts.append(get_project_summary(project.id))
	return " · ".join(parts)

## Every project's state as plain data, for an NPC's conversation context.
func get_context_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for project: TownProjectData in TownProjectData.find_all():
		if project == null:
			continue
		var progress: Dictionary = {}
		for raw_id: Variant in project.requirements.keys():
			var item_id := StringName(String(raw_id))
			progress[String(item_id)] = {
				"donated": get_progress(project.id, item_id),
				"required": project.get_required_quantity(item_id),
			}
		result.append({
			"id": String(project.id),
			"name": project.display_name,
			"location_id": String(project.location_id),
			"available": is_available(project.id),
			"completed": is_completed(project.id),
			"claimed": is_claimed(project.id),
			"progress": progress,
		})
	return result

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
		if required <= 0 or SaveValues.count(progress.get(String(raw_id), 0)) < required:
			return false
	return not project.requirements.is_empty()

func _item_name(item_id: StringName) -> String:
	var item := ItemData.find(item_id)
	return item.display_name if item != null else String(item_id).capitalize()

func _get_all_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(STATE_KEY, {})
	return raw.duplicate(true) if raw is Dictionary else {}

func _set_state(project_id: StringName, state: Dictionary) -> void:
	var all_state := _get_all_state()
	all_state[String(project_id)] = state.duplicate(true)
	WorldState.set_value(STATE_KEY, all_state)
	project_changed.emit(project_id, state.duplicate(true))
