class_name StateMachine
extends RefCounted

## A light state machine: named states, one of them current, each with what
## it does when it is entered, on every update and when it is left, all
## optional. A creature's idle, chase and attack, a door's shut, opening and
## open. Its owner calls `update()` from its own `_process()` or
## `_physics_process()`; a state moves the machine on with `change()`.
##
##     _machine.add_state(&"idle", _idle)
##     _machine.add_state(&"chase", _chase, _start_chase)
##     _machine.start(&"idle")
##
## A change asked for while another is under way (a state's enter or exit
## changes again) happens once that one is done, so every state that is
## entered is also left in order. States that keep handing over to each other
## on entering stop after `MAX_CHAINED_CHANGES`, with a warning.

## The machine left `from` (empty when it starts) for `to`.
signal state_changed(from: StringName, to: StringName)

## How many changes one `change()` makes at most, the ones its states ask for
## on the way included.
const MAX_CHAINED_CHANGES := 64

# name -> {"update": Callable, "enter": Callable, "exit": Callable}
var _states: Dictionary[StringName, Dictionary] = {}
var _state: StringName = &""
var _time_in_state := 0.0
var _changing := false
var _queued: Array[StringName] = []

## Adds the state `name`: `update` is called with the seconds since the last
## update, `enter` and `exit` without arguments. Returns the machine, so the
## states can be added in a chain.
func add_state(name: StringName, update := Callable(), enter := Callable(), exit := Callable()) -> StateMachine:
	_states[name] = {"update": update, "enter": enter, "exit": exit}
	return self

## Whether the machine has the state `name`.
func has_state(name: StringName) -> bool:
	return _states.has(name)

## Enters the first state; false when the machine has no state `name`.
func start(name: StringName) -> bool:
	return change(name)

## Leaves the current state for `name`: false when the machine has no such
## state or is in it already. A change asked for during another is queued to
## happen after it, and true then.
func change(name: StringName) -> bool:
	if not _states.has(name):
		push_warning("StateMachine: no state '%s'" % name)
		return false
	if _changing:
		_queued.append(name)
		return true
	if name == _state:
		return false
	_changing = true
	_switch(name)
	var changes := 1
	while not _queued.is_empty():
		var next: StringName = _queued.pop_front()
		if next == _state:
			continue
		if changes >= MAX_CHAINED_CHANGES:
			push_warning("StateMachine: states keep changing on entering; stopped in '%s'" % _state)
			_queued.clear()
			break
		_switch(next)
		changes += 1
	_changing = false
	return true

## Runs the current state's update with `delta` seconds.
func update(delta: float) -> void:
	if _state == &"":
		return
	_time_in_state += delta
	var update_state: Callable = _states[_state]["update"]
	if update_state.is_valid():
		update_state.call(delta)

## The current state; empty before `start()`.
func get_state() -> StringName:
	return _state

## Whether the current state is `name`.
func is_in(name: StringName) -> bool:
	return _state == name

## Seconds of updates since the current state was entered.
func get_time_in_state() -> float:
	return _time_in_state

func _switch(name: StringName) -> void:
	var previous := _state
	if previous != &"":
		var exit_state: Callable = _states[previous]["exit"]
		if exit_state.is_valid():
			exit_state.call()
	_state = name
	_time_in_state = 0.0
	var enter_state: Callable = _states[name]["enter"]
	if enter_state.is_valid():
		enter_state.call()
	state_changed.emit(previous, name)
