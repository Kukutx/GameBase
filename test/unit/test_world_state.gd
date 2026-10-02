extends GutTest

func test_world_state_round_trips_flags() -> void:
	var state := PersistentWorldState.new()
	add_child_autofree(state)
	state.set_value(&"pickup:berry_01", true)
	state.set_value(&"quest:intro", 2)

	var restored := PersistentWorldState.new()
	add_child_autofree(restored)
	restored.load_save_data(state.to_save_data())

	assert_true(restored.get_bool(&"pickup:berry_01"))
	assert_eq(int(restored.get_value(&"quest:intro", 0)), 2)

func test_world_state_safely_replaces_values_across_incompatible_types() -> void:
	var state := PersistentWorldState.new()
	add_child_autofree(state)
	var observed := {"count": 0}
	state.changed.connect(func(_key: StringName, _value: Variant) -> void: observed["count"] = int(observed["count"]) + 1)
	state.set_value(&"schema:evolving", 7)
	state.set_value(&"schema:evolving", {"version": 2})
	assert_eq(state.get_value(&"schema:evolving"), {"version": 2})
	assert_eq(int(observed["count"]), 2)
	# Equal same-typed values remain a no-op.
	state.set_value(&"schema:evolving", {"version": 2})
	assert_eq(int(observed["count"]), 2)

func test_world_state_bool_flags_do_not_treat_malformed_truthy_values_as_true() -> void:
	var state := PersistentWorldState.new()
	add_child_autofree(state)
	state.load_save_data({
		"flag:dict": {"truthy": true},
		"flag:string": "true",
		"flag:real": true,
	})
	assert_false(state.get_bool(&"flag:dict"))
	assert_false(state.get_bool(&"flag:string"))
	assert_true(state.get_bool(&"flag:real"))
	assert_true(state.get_bool(&"flag:dict", true))

func test_world_state_erases_values() -> void:
	var state := PersistentWorldState.new()
	add_child_autofree(state)
	state.set_value(&"door:opened", true)
	state.erase(&"door:opened")

	assert_false(state.get_bool(&"door:opened"))
