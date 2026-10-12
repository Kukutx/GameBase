class_name GameEventListener
extends RefCounted

## Listens to one event (`GameEvent`, `"Autoload.signal"`) and calls
## `on_event` with the event's arguments by name, a Dictionary, each time it
## fires, from `start()` until `stop()` or until the listener is freed. Its
## owner keeps it: the autoload holds no reference to it.

## The event listened to.
var event: StringName
## The arguments' names, in their order.
var arg_names: PackedStringArray
## The arguments' types, name -> Variant.Type (`GameEvent.get_args()`).
var arg_types: Dictionary

var _on_event: Callable
var _source: Node

func _init(listened: StringName, on_event: Callable) -> void:
	event = listened
	_on_event = on_event

## Starts listening; false when the event is no signal of an autoload.
func start() -> bool:
	stop()
	_source = GameEvent.find_source(event)
	if _source == null:
		return false
	arg_types = GameEvent.get_args(event)
	arg_names = PackedStringArray(arg_types.keys())
	_source.connect(_signal_name(), _relay)
	return true

## Stops listening.
func stop() -> void:
	# The source may already be gone (freed before the listener's owner at exit).
	if is_instance_valid(_source) and _source.is_connected(_signal_name(), _relay):
		_source.disconnect(_signal_name(), _relay)
	_source = null

## Whether it listens.
func is_listening() -> bool:
	return is_instance_valid(_source) and _source.is_connected(_signal_name(), _relay)

func _signal_name() -> String:
	return String(event).get_slice(".", 1)

func _relay(...values: Array) -> void:
	var args: Dictionary = {}
	for index: int in mini(arg_names.size(), values.size()):
		args[arg_names[index]] = values[index]
	_on_event.call(args)
