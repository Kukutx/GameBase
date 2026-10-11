class_name NpcContextService
extends Node

const CONTEXT_VERSION := 1
const MEMORY_LIMIT := 12

func build_context(npc_id: StringName, actor: Node = null) -> Dictionary:
	var profile := ContentDB.get_npc(npc_id)
	if profile == null:
		return {}
	var location := ContentDB.get_current_location(get_tree())
	var location_id := location.id if location != null else &""
	var active_events: Array[Dictionary] = []
	for event: CalendarEventData in EventState.get_active_events(location_id):
		active_events.append({
			"id": String(event.id),
			"name": event.display_name,
			"location_id": String(event.location_id),
		})
	var world_facts: Dictionary = {}
	for world_key: StringName in profile.context_world_keys:
		world_facts[String(world_key)] = WorldState.get_value(world_key)
	var pending_heart_event := HeartEvents.get_pending_event(npc_id)
	var seen_heart_events: Array[String] = []
	for event_id: StringName in HeartEvents.get_seen_event_ids(npc_id):
		seen_heart_events.append(String(event_id))
	return {
		"version": CONTEXT_VERSION,
		"npc": {
			"id": String(profile.id),
			"name": profile.display_name,
			"role": profile.role,
			"background": profile.background,
			"personality": profile.personality,
			"speaking_style": profile.speaking_style,
			"home_location_id": String(profile.home_location_id),
			"default_location_id": String(profile.default_location_id),
			"birthday_season": profile.birthday_season,
			"birthday_day": profile.birthday_day,
			"birthday_today": profile.is_birthday(),
		},
		"relationship": {
			"points": RelationshipState.get_points(npc_id),
			"hearts": RelationshipState.get_hearts(npc_id),
			"seen_heart_events": seen_heart_events,
			"pending_heart_event": String(pending_heart_event.id) if pending_heart_event != null else "",
		},
		"world": {
			"day": WorldClock.day,
			"season": WorldClock.get_season_name(),
			"day_of_season": WorldClock.get_day_of_season(),
			"weekday": posmod(WorldClock.day - 1, 7),
			"minute_of_day": WorldClock.minute_of_day,
			"time_text": WorldClock.get_time_text(),
			"weather": WeatherState.get_weather_name(),
			"location_id": String(location_id),
			"location_name": location.display_name if location != null else "",
			"active_events": active_events,
			"town_projects": _get_town_project_context(),
			"facts": world_facts,
		},
		"player": {
			"energy": PlayerState.energy,
			"max_energy": PlayerState.max_energy,
			"money": PlayerState.money,
			"selected_item_id": String(PlayerState.get_selected_item_id()),
			"inventory": InventoryState.get_entries(),
			"skills": Skills.to_save_data(),
			"actor_name": actor.name if actor != null else "Player",
		},
		"quests": QuestState.get_journal_entries(),
		"npc_state": _get_runtime_npc_state(npc_id),
		"memory": {
			"facts": NpcMemory.get_facts(npc_id),
			"recent_messages": NpcMemory.get_recent_messages(npc_id, MEMORY_LIMIT),
		},
	}

func build_context_json(npc_id: StringName, actor: Node = null) -> String:
	return JSON.stringify(build_context(npc_id, actor), "\t")

func _get_runtime_npc_state(npc_id: StringName) -> Dictionary:
	for node: Node in get_tree().get_nodes_in_group("npc"):
		if node.has_method("get_npc_id") and node.call("get_npc_id") == npc_id:
			var activity := ""
			var schedule := node.get_node_or_null("Schedule") as NpcSchedule
			if schedule != null:
				activity = schedule.current_activity
			return {
				"activity": activity,
				"visible_in_current_location": node.visible,
			}
	return {
		"activity": "",
		"visible_in_current_location": false,
	}

func _get_town_project_context() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for project: TownProjectData in ContentDB.get_all_town_projects():
		if project == null:
			continue
		var progress: Dictionary = {}
		for raw_id: Variant in project.requirements.keys():
			var item_id := StringName(String(raw_id))
			progress[String(item_id)] = {
				"donated": TownProjects.get_progress(project.id, item_id),
				"required": project.get_required_quantity(item_id),
			}
		result.append({
			"id": String(project.id),
			"name": project.display_name,
			"location_id": String(project.location_id),
			"available": TownProjects.is_available(project.id),
			"completed": TownProjects.is_completed(project.id),
			"claimed": TownProjects.is_claimed(project.id),
			"progress": progress,
		})
	return result
