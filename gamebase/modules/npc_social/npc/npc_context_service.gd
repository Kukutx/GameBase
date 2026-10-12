class_name NpcContextService
extends Node

## What an NPC knows when it talks: who it is, the relationship, the world, the
## player and its memory, then what every module the game has tells about its
## own systems (`GameModule.get_facts()`: the player's inventory, the events
## under way, the quests), each section under its own key. A section named as
## one of the context's own keys (npc, relationship, world, player, ...) is
## left out.

const CONTEXT_VERSION := 2
const MEMORY_LIMIT := 12

func build_context(npc_id: StringName, actor: Node = null) -> Dictionary:
	var profile := NpcProfileData.find(npc_id)
	if profile == null:
		return {}
	var location := WorldLocationData.find_current(get_tree())
	var location_id := location.id if location != null else &""
	var world_facts: Dictionary = {}
	for world_key: StringName in profile.context_world_keys:
		world_facts[String(world_key)] = WorldState.get_value(world_key)
	var pending_heart_event := HeartEvents.get_pending_event(npc_id)
	var seen_heart_events: Array[String] = []
	for event_id: StringName in HeartEvents.get_seen_event_ids(npc_id):
		seen_heart_events.append(String(event_id))
	var context := {
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
			"weekday": GameCalendar.current().get_weekday(WorldClock.day),
			"minute_of_day": WorldClock.minute_of_day,
			"time_text": WorldClock.get_time_text(),
			"weather": WeatherState.get_weather_name(),
			"location_id": String(location_id),
			"location_name": location.display_name if location != null else "",
			"facts": world_facts,
		},
		"player": {
			"vitals": _vitals(),
			"actor_name": actor.name if actor != null else "Player",
		},
		"npc_state": _get_runtime_npc_state(npc_id),
		"memory": {
			"facts": NpcMemory.get_facts(npc_id),
			"recent_messages": NpcMemory.get_recent_messages(npc_id, MEMORY_LIMIT),
		},
	}
	var module_facts := GameModules.get_facts()
	for section: Variant in module_facts:
		if not context.has(section):
			context[section] = module_facts[section]
	return context

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

# The player's vitals as vital id -> {"value", "maximum"}.
func _vitals() -> Dictionary:
	var vitals := {}
	for vital: VitalData in VitalData.find_all():
		vitals[String(vital.id)] = {"value": Vitals.get_value(vital.id), "maximum": Vitals.get_maximum(vital.id)}
	return vitals
