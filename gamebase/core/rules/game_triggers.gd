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
## set it off, each in its type, without checking its condition again, so it
## gives what it promised once. One whose first action failed gave nothing and
## fires anew, and so does one whose actions changed since it stopped (a
## content update), since where it stopped no longer means the same.

signal trigger_fired(trigger_id: StringName)

## How deep triggers may set off one another (a trigger's action firing an
## event another trigger listens to) before the chain is cut as a loop.
const MAX_DEPTH := 8
## The world's key of the triggers' state: {"fired": [trigger id], "pending":
## {trigger id: {"done": how many actions ran, "actions": the fingerprint of
## the actions it ran (`get_actions_fingerprint()`), "event": {argument:
## {"type": its Variant.Type, "value": the value as JSON holds it}}}}}.
const STATE_KEY := &"triggers:state"
## The types of value an event of a once trigger may pass: those a save keeps
## for a pending trigger. Content checks reject an event that declares another,
## and a once trigger whose event passes a value that is not of its declared
## type (or one it converts to without loss) or that a save could not keep
## exactly does not run, with a warning.
const SAVED_TYPES: Array[int] = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]

# event -> Array[TriggerData]
var _by_event: Dictionary = {}
# event -> argument names, in their order
var _arg_names: Dictionary = {}
# event -> {argument name: its declared type}
var _arg_types: Dictionary = {}
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
			_arg_types[trigger.event] = trigger.get_event_args()
			_arg_names[trigger.event] = PackedStringArray(_arg_types[trigger.event].keys())
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
	return not _pending(TriggerData.find(trigger_id)).is_empty()

## What identifies `trigger`'s actions as they are: a pending trigger resumes
## only at the actions it stopped in.
static func get_actions_fingerprint(trigger: TriggerData) -> String:
	return ("%s\n%s" % [trigger.event, "\n".join(trigger.actions)]).sha256_text()

## Fires the triggers on `event` with the event's arguments by name.
func fire(event: StringName, args: Dictionary) -> void:
	if GameSession.is_changing():
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
			var pending := _pending(trigger)
			var declared: Variant = null
			if pending.is_empty():
				declared = _as_declared(trigger, args, _arg_types.get(event, {}))
				if declared == null or not GameRules.check(trigger.condition, {"event": declared}):
					continue
			_running[trigger.id] = true
			if pending.is_empty():
				completed = _run_once(trigger, declared, 0)
			else:
				completed = _run_once(trigger, pending["event"], pending["done"])
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
	# Nothing ran this time: the action at `first` failed, or the actions
	# cannot run as written (-1). The state stays as it was.
	if done <= first:
		return false
	var completed := done >= GameRules.count_actions(trigger.actions)
	var state := _get_state()
	var id := String(trigger.id)
	if completed:
		(state["pending"] as Dictionary).erase(id)
		(state["fired"] as Array).append(id)
	else:
		(state["pending"] as Dictionary)[id] = _saved_pending(trigger, done, event)
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
	_arg_types.clear()

# A cleared or loaded world keeps only what current once triggers left: the
# ones that fired, and the pending ones that have not and can resume
# (`_resume_point()`). A save names current content only: a pending trigger
# whose stored value is an id the content no longer has is dropped.
func _on_world_state_changed(key: StringName, _value: Variant) -> void:
	# A state saved as null, or of any shape, is reconciled like any other.
	if key != &"" or not WorldState.has_value(STATE_KEY):
		return
	var saved := _get_state()
	var kept := {"fired": [], "pending": {}}
	for id: Variant in saved["fired"]:
		if (id is String or id is StringName) and _is_once(id) and not (kept["fired"] as Array).has(String(id)):
			(kept["fired"] as Array).append(String(id))
	var pending: Dictionary = saved["pending"]
	for id: Variant in pending:
		if not _is_once(id) or (kept["fired"] as Array).has(String(id)):
			continue
		var trigger := TriggerData.find(StringName(String(id)))
		var point := _resume_point(trigger, pending[id])
		if not point.is_empty():
			(kept["pending"] as Dictionary)[String(id)] = _saved_pending(trigger, point["done"], point["event"])
	_set_state(kept)

func _is_once(id: Variant) -> bool:
	var trigger := TriggerData.find(StringName(String(id))) if id is String or id is StringName else null
	return trigger != null and trigger.once

# Where `trigger` resumes, as {"done": int, "event": the event's values in
# their types}; empty when it is not pending.
func _pending(trigger: TriggerData) -> Dictionary:
	if trigger == null:
		return {}
	return _resume_point(trigger, (_read_state(&"pending", {}) as Dictionary).get(String(trigger.id)))

# Where `trigger` resumes from the pending `entry` (`_saved_pending()`), as
# {"done": int, "event": the event's values in their types}; empty unless the
# entry was written for the actions as they are, ran at least one of them and
# not all, keeps a value of each argument of the event, and the remaining
# actions can run with those values. A saved number comes back as a float.
func _resume_point(trigger: TriggerData, entry: Variant) -> Dictionary:
	if trigger == null or not trigger.once or not (entry is Dictionary):
		return {}
	var fingerprint: Variant = (entry as Dictionary).get("actions")
	if not (fingerprint is String) or fingerprint != get_actions_fingerprint(trigger):
		return {}
	var done: Variant = SaveValues.whole_number((entry as Dictionary).get("done"))
	if done == null or int(done) < 1 or int(done) >= GameRules.count_actions(trigger.actions):
		return {}
	var values: Variant = (entry as Dictionary).get("event")
	var names := trigger.get_event_args()
	if not (values is Dictionary) or (values as Dictionary).size() != names.size():
		return {}
	var event := {}
	for name: String in names:
		var value := _loaded_value((values as Dictionary).get(name))
		# A value of a type the event no longer declares is not what it passes.
		if value.is_empty() or typeof(value[0]) != int(names[name]):
			return {}
		event[name] = value[0]
	if not GameRules.can_run_actions_from(trigger.actions, int(done), {"event": event}):
		return {}
	return {"done": int(done), "event": event}

# The pending entry of `trigger`, stopped after `done` of its actions ran on
# `event`, as the world keeps it.
static func _saved_pending(trigger: TriggerData, done: int, event: Dictionary) -> Dictionary:
	var values := {}
	for name: String in event:
		values[name] = _saved_value(event[name])
	return {"done": done, "actions": get_actions_fingerprint(trigger), "event": values}

# `args`, the event's arguments, each in the type `types` declares for it, so
# what a once trigger runs on is what a save keeps and gives back if it is
# left pending; null, with a warning, when a value is not of its declared type
# or one it converts to without loss (an int for a float, a String for a
# StringName and back), or a save could not keep it exactly.
static func _as_declared(trigger: TriggerData, args: Dictionary, types: Dictionary) -> Variant:
	var declared := {}
	for name: String in types:
		var value: Variant = args.get(name)
		var type := int(types[name])
		if type == TYPE_FLOAT and value is int:
			value = float(value)
		elif type == TYPE_STRING_NAME and value is String:
			value = StringName(value)
		elif type == TYPE_STRING and value is StringName:
			value = String(value)
		var exact := typeof(value) == type and SAVED_TYPES.has(type)
		if exact and value is float:
			exact = is_finite(value)
		elif exact and value is int:
			exact = value <= SaveValues.MAX_WHOLE_INT and value >= -SaveValues.MAX_WHOLE_INT
		if not exact:
			push_warning("GameTriggers: once trigger '%s' does not run: '%s' passed %s = %s, which is not a %s a save keeps" % [trigger.id, trigger.event, name, value, type_string(type)])
			return null
		declared[name] = value
	return declared

# An event's value (`SAVED_TYPES`) as a save keeps it: its type, and the value
# as JSON holds it.
static func _saved_value(value: Variant) -> Dictionary:
	return {"type": typeof(value), "value": String(value) if value is StringName else value}

# The value `saved` (`_saved_value()`) keeps, back in its type, as [value];
# empty when `saved` is not of that shape.
static func _loaded_value(saved: Variant) -> Array:
	if not (saved is Dictionary):
		return []
	var type: Variant = SaveValues.whole_number((saved as Dictionary).get("type"))
	var value: Variant = (saved as Dictionary).get("value")
	if type == null:
		return []
	match int(type):
		TYPE_BOOL:
			return [value] if value is bool else []
		TYPE_INT:
			var number: Variant = SaveValues.whole_number(value)
			return [] if number == null else [int(number)]
		TYPE_FLOAT:
			return [float(value)] if (value is float or value is int) and is_finite(float(value)) else []
		TYPE_STRING:
			return [value] if value is String else []
		TYPE_STRING_NAME:
			return [StringName(value)] if value is String else []
	return []

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
