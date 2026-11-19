extends GutTest

## A light state machine (`StateMachine`): states entered, updated and left in
## order, and a change asked for during another.

var _machine: StateMachine
var _log: Array[String] = []

func before_each() -> void:
	_machine = StateMachine.new()
	_log.clear()

func test_it_enters_updates_and_leaves_states_in_order() -> void:
	_machine.add_state(&"idle", func(delta: float) -> void: _log.append("idle %s" % delta), _note.bind("enter idle"), _note.bind("exit idle")) \
		.add_state(&"chase", Callable(), _note.bind("enter chase"))
	watch_signals(_machine)
	assert_eq(_machine.get_state(), &"")
	_machine.update(1.0)
	assert_true(_log.is_empty(), "nothing runs before the start")
	assert_true(_machine.start(&"idle"))
	_machine.update(0.5)
	_machine.update(0.5)
	assert_eq(_machine.get_time_in_state(), 1.0)
	assert_false(_machine.change(&"idle"), "in it already")
	assert_true(_machine.change(&"chase"))
	assert_true(_machine.is_in(&"chase"))
	assert_eq(_machine.get_time_in_state(), 0.0)
	_machine.update(1.0)
	assert_eq(_log, ["enter idle", "idle 0.5", "idle 0.5", "exit idle", "enter chase"] as Array[String])
	assert_signal_emitted_with_parameters(_machine, "state_changed", [&"", &"idle"], 0)
	assert_signal_emitted_with_parameters(_machine, "state_changed", [&"idle", &"chase"], 1)

func test_a_change_during_another_happens_after_it() -> void:
	# Raising the alarm sends the guard fleeing at once.
	var raise_alarm := func() -> void:
		_log.append("enter alarm")
		_machine.change(&"flee")
	_machine.add_state(&"guard", Callable(), _note.bind("enter guard"), _note.bind("exit guard")) \
		.add_state(&"alarm", Callable(), raise_alarm, _note.bind("exit alarm")) \
		.add_state(&"flee", Callable(), _note.bind("enter flee"))
	_machine.start(&"guard")
	assert_true(_machine.change(&"alarm"))
	assert_eq(_machine.get_state(), &"flee")
	assert_eq(_log, ["enter guard", "exit guard", "enter alarm", "exit alarm", "enter flee"] as Array[String], "every state entered is left in order")

func test_an_unknown_state_is_refused() -> void:
	_machine.add_state(&"idle")
	assert_true(_machine.has_state(&"idle"))
	assert_false(_machine.start(&"fixture_missing"))
	assert_push_warning("no state 'fixture_missing'")
	assert_eq(_machine.get_state(), &"")

func test_states_that_keep_handing_over_stop_with_a_warning() -> void:
	var to_chase := func() -> void: _machine.change(&"chase")
	var to_idle := func() -> void: _machine.change(&"idle")
	_machine.add_state(&"idle", Callable(), to_chase).add_state(&"chase", Callable(), to_idle)
	assert_true(_machine.start(&"idle"))
	assert_push_warning("states keep changing on entering")
	assert_true(_machine.has_state(_machine.get_state()), "it stops in one of them")

func _note(line: String) -> void:
	_log.append(line)
