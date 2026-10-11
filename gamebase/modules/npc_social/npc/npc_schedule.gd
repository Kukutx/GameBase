class_name NpcSchedule
extends Node

signal activity_changed(activity: String)
signal presence_changed(present: bool)

@export var actor: CharacterBody2D
@export var navigation_agent: NavigationAgent2D
@export var entries: Array[NpcScheduleEntry] = []
@export var current_location_id: StringName
@export_range(1.0, 300.0, 1.0) var move_speed := 48.0
@export_range(1.0, 32.0, 1.0) var arrival_distance := 4.0

var current_activity := "Idle"
var current_present := true
var _target_position := Vector2.ZERO
var _has_target := false
var _navigation_ready := false

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_minute_changed)
	WorldClock.day_changed.connect(_on_day_changed)
	if navigation_agent != null:
		navigation_agent.path_desired_distance = arrival_distance
		navigation_agent.target_desired_distance = arrival_distance
	_activate_navigation.call_deferred()
	_apply_schedule(WorldClock.day, WorldClock.minute_of_day)

func _activate_navigation() -> void:
	await get_tree().physics_frame
	_navigation_ready = true
	_sync_navigation_target()

func _physics_process(_delta: float) -> void:
	if actor == null or not current_present or not _has_target:
		return
	var offset := _target_position - actor.global_position
	if offset.length() <= arrival_distance:
		_finish_movement()
		return

	var next_position := _target_position
	if navigation_agent != null and _navigation_ready:
		var candidate := navigation_agent.get_next_path_position()
		if not navigation_agent.is_navigation_finished() and candidate.distance_squared_to(actor.global_position) > 0.01:
			next_position = candidate

	var direction := actor.global_position.direction_to(next_position)
	if direction.length_squared() <= 0.001:
		direction = offset.normalized()
	actor.velocity = direction * move_speed
	actor.move_and_slide()

func get_entry_for_minute(minute_of_day: int, target_day: int = -1) -> NpcScheduleEntry:
	if entries.is_empty():
		return null
	var resolved_day := WorldClock.day if target_day < 1 else target_day
	var selected: NpcScheduleEntry = null
	var selected_priority := -100000
	var selected_minute := -1
	for entry: NpcScheduleEntry in entries:
		if entry == null or not entry.matches(resolved_day, minute_of_day):
			continue
		if entry.minute_of_day <= minute_of_day and _is_better(entry.priority, entry.minute_of_day, selected_priority, selected_minute):
			selected = entry
			selected_priority = entry.priority
			selected_minute = entry.minute_of_day
	if selected != null:
		return selected

	# Before today's first route begins, the NPC should still be where the last
	# valid route from the previous day left them. Looking at today's final route
	# here causes Monday pre-dawn to use Monday evening, and breaks weekday-based
	# cross-town schedules by teleporting NPCs home at midnight.
	var previous_day := maxi(resolved_day - 1, 1)
	var fallback: NpcScheduleEntry = null
	var fallback_priority := -100000
	var fallback_minute := -1
	for entry: NpcScheduleEntry in entries:
		if entry == null or not entry.matches(previous_day, minute_of_day):
			continue
		if _is_better(entry.priority, entry.minute_of_day, fallback_priority, fallback_minute):
			fallback = entry
			fallback_priority = entry.priority
			fallback_minute = entry.minute_of_day
	return fallback

func set_current_location(location_id: StringName) -> void:
	current_location_id = location_id
	_apply_schedule(WorldClock.day, WorldClock.minute_of_day)

func is_entry_present_here(entry: NpcScheduleEntry) -> bool:
	return entry != null and (entry.location_id == &"" or current_location_id == &"" or entry.location_id == current_location_id)

func has_navigation_path() -> bool:
	return navigation_agent != null and _navigation_ready and not navigation_agent.is_navigation_finished()

func _on_minute_changed(day: int, minute_of_day: int) -> void:
	_apply_schedule(day, minute_of_day)

func _on_day_changed(day: int) -> void:
	_apply_schedule(day, WorldClock.minute_of_day)

func _apply_schedule(day: int, minute_of_day: int) -> void:
	var entry := get_entry_for_minute(minute_of_day, day)
	if entry == null or actor == null:
		_set_presence(false)
		return
	var present_here := is_entry_present_here(entry)
	_set_presence(present_here)
	if not present_here:
		actor.velocity = Vector2.ZERO
		_has_target = false
		return
	if current_activity != entry.activity:
		current_activity = entry.activity
		activity_changed.emit(current_activity)
	if not actor.global_position.is_equal_approx(entry.target_position):
		_target_position = entry.target_position
		_has_target = true
		_sync_navigation_target()
	else:
		_finish_movement()

func _sync_navigation_target() -> void:
	if navigation_agent == null or not _navigation_ready or not _has_target:
		return
	navigation_agent.target_position = _target_position

func _finish_movement() -> void:
	if actor == null:
		return
	actor.global_position = _target_position
	actor.velocity = Vector2.ZERO
	_has_target = false

func _set_presence(value: bool) -> void:
	if current_present == value:
		return
	current_present = value
	presence_changed.emit(current_present)

func _is_better(priority: int, minute: int, current_priority: int, current_minute: int) -> bool:
	return priority > current_priority or (priority == current_priority and minute > current_minute)
