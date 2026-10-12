class_name GameTriggerService
extends Node

## Runs the game's triggers (`TriggerData`): listens to every event a trigger
## names and, when one fires, runs the actions of each trigger on it whose
## condition holds. The condition and the actions see the event's arguments
## by name under the context's "event" key. What the services announce while a
## save is restored or a new game resets them is not play and fires nothing.
## A once trigger whose action failed keeps in the world how many of its
## actions ran, and its next firing resumes at the one that failed.

signal trigger_fired(trigger_id: StringName)

## How deep triggers may set off one another (a trigger's action firing an
## event another trigger listens to) before the chain is cut as a loop.
const MAX_DEPTH := 8

# event -> Array[TriggerData]
var _by_event: Dictionary = {}
# event -> argument names, in their order
var _arg_names: Dictionary = {}
# event -> the callable connected to its signal
var _connections: Dictionary = {}
var _depth := 0
# Once triggers whose actions are running, so they do not set themselves off.
var _running: Dictionary = {}

func _ready() -> void:
	connect_triggers()
	WorldState.changed.connect(_on_world_state_changed)

func _exit_tree() -> void:
	_disconnect_all()

## Listens to the events of the active content's triggers
## (`ContentRegistry.active`), dropping what it listened to before.
func connect_triggers() -> void:
	_disconnect_all()
	for trigger: TriggerData in TriggerData.find_all():
		var source := trigger.get_source()
		if source == null:
			continue
		if not _by_event.has(trigger.event):
			_by_event[trigger.event] = []
			_arg_names[trigger.event] = PackedStringArray(trigger.get_event_args().keys())
			var callable := _on_event.bind(trigger.event)
			source.connect(String(trigger.event).get_slice(".", 1), callable)
			_connections[trigger.event] = [source, callable]
		(_by_event[trigger.event] as Array).append(trigger)

## Whether the trigger already fired in this world, for one that fires once.
func has_fired(trigger_id: StringName) -> bool:
	return WorldState.get_bool(_fired_key(trigger_id))

## Fires the triggers on `event` with the event's arguments by name.
func fire(event: StringName, args: Dictionary) -> void:
	if GameSaveManager.is_restoring() or GameSession.is_starting_new_game():
		return
	if _depth >= MAX_DEPTH:
		push_warning("GameTriggers: '%s' fired %d triggers deep; a trigger sets itself off" % [event, MAX_DEPTH])
		return
	_depth += 1
	var context := {"event": args}
	for trigger: TriggerData in _by_event.get(event, []):
		if trigger.once and (has_fired(trigger.id) or _running.has(trigger.id)):
			continue
		var times := 1 if trigger.repeat_per == &"" else int(args.get(String(trigger.repeat_per), 0))
		if times <= 0 or not GameRules.check(trigger.condition, context):
			continue
		_running[trigger.id] = true
		var completed := _run_once(trigger, context) if trigger.once else _run(trigger, times, context)
		_running.erase(trigger.id)
		if completed:
			trigger_fired.emit(trigger.id)
	_depth -= 1

func _run(trigger: TriggerData, times: int, context: Dictionary) -> bool:
	for _time: int in times:
		if not GameRules.run_actions(trigger.actions, context):
			return false
	return true

# Runs a once trigger's actions from the first that has not run in this world.
# An action that failed (a full inventory) leaves it to fire again from there;
# only one whose actions all ran counts as fired.
func _run_once(trigger: TriggerData, context: Dictionary) -> bool:
	var total := GameRules.count_actions(trigger.actions)
	var done := GameRules.run_actions_from(trigger.actions, WorldState.get_int(_progress_key(trigger.id)), context)
	if done < total:
		WorldState.set_value(_progress_key(trigger.id), done)
		return false
	WorldState.erase(_progress_key(trigger.id))
	WorldState.set_value(_fired_key(trigger.id), true)
	return true

func _on_event(...values: Array) -> void:
	var event: StringName = values.pop_back()
	var names: PackedStringArray = _arg_names.get(event, PackedStringArray())
	var args: Dictionary = {}
	for index: int in mini(names.size(), values.size()):
		args[names[index]] = values[index]
	fire(event, args)

func _disconnect_all() -> void:
	for event: StringName in _connections:
		# The source may already be gone (freed before this service at exit).
		var source: Variant = _connections[event][0]
		var callable: Callable = _connections[event][1]
		var signal_name := String(event).get_slice(".", 1)
		if is_instance_valid(source) and (source as Node).is_connected(signal_name, callable):
			(source as Node).disconnect(signal_name, callable)
	_connections.clear()
	_by_event.clear()
	_arg_names.clear()

# A cleared or loaded world keeps only the marks of current once triggers: that
# one fired, exactly true, and how many actions of one that has not ran, a
# count short of all of them. A save names current content only.
func _on_world_state_changed(key: StringName, _value: Variant) -> void:
	if key != &"":
		return
	var world := WorldState.to_save_data()
	for world_key: String in world:
		var parts := world_key.split(":")
		if parts.size() != 3 or parts[0] != "trigger" or not (parts[2] == "fired" or parts[2] == "progress"):
			continue
		var trigger := TriggerData.find(StringName(parts[1]))
		var mark: Variant = world[world_key]
		var kept := trigger != null and trigger.once
		if kept and parts[2] == "fired":
			kept = mark is bool and mark
		elif kept:
			# A saved count comes back as a float.
			var count := WorldState.get_int(StringName(world_key))
			kept = (mark is int or mark is float) and count == mark and count > 0 and count < GameRules.count_actions(trigger.actions) and not has_fired(trigger.id)
		if not kept:
			WorldState.erase(StringName(world_key))

func _fired_key(trigger_id: StringName) -> StringName:
	return StringName("trigger:%s:fired" % trigger_id)

func _progress_key(trigger_id: StringName) -> StringName:
	return StringName("trigger:%s:progress" % trigger_id)
