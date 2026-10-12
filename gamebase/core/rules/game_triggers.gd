class_name GameTriggerService
extends Node

## Runs the game's triggers (`TriggerData`): listens to every event a trigger
## names and, when one fires, runs the actions of each trigger on it whose
## condition holds. The condition and the actions see the event's arguments
## by name under the context's "event" key. What the services announce while a
## save is restored or a new game resets them is not play and fires nothing.
##
## The world keeps, under `STATE_KEY`, the once triggers that fired and the
## pending ones: those whose actions stopped at one that failed (a full
## inventory) after others ran. The next time its event fires, a pending
## trigger resumes at the failed action with the arguments of the event that
## set it off, without checking its condition again, so it gives what it
## promised once. One whose first action failed gave nothing and fires anew.

signal trigger_fired(trigger_id: StringName)

## How deep triggers may set off one another (a trigger's action firing an
## event another trigger listens to) before the chain is cut as a loop.
const MAX_DEPTH := 8
## The world's key of the triggers' state: {"fired": [trigger id], "pending":
## {trigger id: {"done": how many actions ran, "event": {argument: value as
## text}}}}.
const STATE_KEY := &"triggers:state"

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
	return (_read_state(&"fired", []) as Array).has(String(trigger_id))

## Whether a once trigger's actions stopped at one that failed and wait for
## its event to fire again.
func is_pending(trigger_id: StringName) -> bool:
	return (_read_state(&"pending", {}) as Dictionary).has(String(trigger_id))

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
		var completed := false
		if trigger.once:
			if _running.has(trigger.id) or has_fired(trigger.id):
				continue
			var pending: Dictionary = (_read_state(&"pending", {}) as Dictionary).get(String(trigger.id), {})
			if pending.is_empty() and not GameRules.check(trigger.condition, context):
				continue
			_running[trigger.id] = true
			if pending.is_empty():
				completed = _run_once(trigger, args, 0)
			else:
				completed = _run_once(trigger, pending["event"], int(pending["done"]))
			_running.erase(trigger.id)
		else:
			var times := 1 if trigger.repeat_per == &"" else int(args.get(String(trigger.repeat_per), 0))
			if times <= 0 or not GameRules.check(trigger.condition, context):
				continue
			completed = _run(trigger, times, context)
		if completed:
			trigger_fired.emit(trigger.id)
	_depth -= 1

func _run(trigger: TriggerData, times: int, context: Dictionary) -> bool:
	for _time: int in times:
		if not GameRules.run_actions(trigger.actions, context):
			return false
	return true

# Runs a once trigger's actions from the one at `first` with the event's
# arguments `event`. When one fails after others ran, the trigger is pending
# at it; when all ran, it fired.
func _run_once(trigger: TriggerData, event: Dictionary, first: int) -> bool:
	var done := GameRules.run_actions_from(trigger.actions, first, {"event": event})
	var completed := done >= GameRules.count_actions(trigger.actions)
	if done == 0:
		return false
	var state := _get_state()
	var id := String(trigger.id)
	if completed:
		(state["pending"] as Dictionary).erase(id)
		(state["fired"] as Array).append(id)
	else:
		var texts := {}
		for name: String in event:
			texts[name] = str(event[name])
		(state["pending"] as Dictionary)[id] = {"done": done, "event": texts}
	_set_state(state)
	return completed

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

# A cleared or loaded world keeps only what current once triggers left: the
# ones that fired, and the pending ones that have not, each past its first
# action and short of all of them, with a text value for every argument of
# its event. A save names current content only.
func _on_world_state_changed(key: StringName, _value: Variant) -> void:
	if key != &"" or WorldState.get_value(STATE_KEY) == null:
		return
	var saved := _get_state()
	var kept := {"fired": [], "pending": {}}
	for id: Variant in saved["fired"]:
		if (id is String or id is StringName) and _is_once(id) and not (kept["fired"] as Array).has(String(id)):
			(kept["fired"] as Array).append(String(id))
	var pending: Dictionary = saved["pending"]
	for id: Variant in pending:
		if _is_once(id) and not (kept["fired"] as Array).has(String(id)) and _is_resumable(TriggerData.find(StringName(String(id))), pending[id]):
			(kept["pending"] as Dictionary)[String(id)] = {"done": int(pending[id]["done"]), "event": pending[id]["event"]}
	_set_state(kept)

func _is_once(id: Variant) -> bool:
	var trigger := TriggerData.find(StringName(String(id))) if id is String or id is StringName else null
	return trigger != null and trigger.once

# Whether `entry` is where `trigger` can resume: a whole count of the actions
# that ran, at least one and short of all of them, and a text value for each
# argument its event has. A saved count comes back as a float.
func _is_resumable(trigger: TriggerData, entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var done: Variant = (entry as Dictionary).get("done")
	var event: Variant = (entry as Dictionary).get("event")
	if not (done is int or done is float) or done != int(done) or int(done) < 1 or int(done) >= GameRules.count_actions(trigger.actions):
		return false
	if not (event is Dictionary) or (event as Dictionary).size() != trigger.get_event_args().size():
		return false
	for name: String in trigger.get_event_args():
		if not ((event as Dictionary).get(name) is String):
			return false
	return true

# A part of the triggers' state as the world holds it, or `empty` when it is
# not of that shape. Read only: `_get_state()` gives a copy to change.
func _read_state(part: StringName, empty: Variant) -> Variant:
	var saved: Variant = WorldState.get_value(STATE_KEY)
	var value: Variant = (saved as Dictionary).get(String(part)) if saved is Dictionary else null
	return value if typeof(value) == typeof(empty) else empty

# A copy of the triggers' state, each part of it in its shape.
func _get_state() -> Dictionary:
	return {"fired": (_read_state(&"fired", []) as Array).duplicate(true), "pending": (_read_state(&"pending", {}) as Dictionary).duplicate(true)}

func _set_state(state: Dictionary) -> void:
	if (state["fired"] as Array).is_empty() and (state["pending"] as Dictionary).is_empty():
		WorldState.erase(STATE_KEY)
	else:
		WorldState.set_value(STATE_KEY, state)
