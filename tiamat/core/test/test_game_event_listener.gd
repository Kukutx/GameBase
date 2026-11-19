extends GutTest

## Listening to an event of an autoload by its name (`GameEventListener`,
## `GameEvent`).

## Stands in for a module's `<Module>Events` autoload.
class FixtureEvents:
	extends Node
	signal harvested(crop_id: StringName, quantity: int)

var _events: FixtureEvents

func before_each() -> void:
	_events = FixtureEvents.new()
	_events.name = "FixtureListenedEvents"
	get_tree().root.add_child(_events)

func after_each() -> void:
	_events.free()

func test_it_passes_the_arguments_by_name_until_it_stops() -> void:
	var heard: Array[Dictionary] = []
	var listener := GameEventListener.new(&"FixtureListenedEvents.harvested", func(args: Dictionary) -> void: heard.append(args))
	assert_true(listener.start())
	assert_eq(listener.arg_types, {"crop_id": TYPE_STRING_NAME, "quantity": TYPE_INT})
	_events.harvested.emit(&"fixture_radish", 3)
	assert_eq(heard, [{"crop_id": &"fixture_radish", "quantity": 3}])
	listener.stop()
	assert_false(listener.is_listening())
	_events.harvested.emit(&"fixture_radish", 1)
	assert_eq(heard.size(), 1, "a stopped listener hears nothing")

func test_an_event_no_autoload_has_is_not_listened_to() -> void:
	for event: StringName in [&"FixtureListenedEvents.missing", &"NoSuchAutoload.harvested", &"no_dot"]:
		var listener := GameEventListener.new(event, func(_args: Dictionary) -> void: pass)
		assert_false(listener.start(), String(event))
		assert_null(GameEvent.find_source(event))
		assert_eq(GameEvent.get_args(event), {})

func test_a_freed_listener_leaves_the_signal() -> void:
	var listener := GameEventListener.new(&"FixtureListenedEvents.harvested", func(_args: Dictionary) -> void: pass)
	assert_true(listener.start())
	assert_eq(_events.harvested.get_connections().size(), 1)
	listener = null
	assert_eq(_events.harvested.get_connections().size(), 0, "the autoload keeps no listener alive")

func test_an_argument_named_after_a_kind_holds_its_ids() -> void:
	var registry := ContentRegistry.new()
	registry.register_kind(&"cue", ContentEntry)
	var expected := {
		"location_id": &"location",
		"spawn_location_id": &"location",
		"audio_cue_id": &"audio_cue",
		"cue_id": &"cue",
		"node_id": &"",
		"location": &"",
		"relocation_id": &"",
	}
	for name: String in expected:
		assert_eq(GameEvent.get_arg_content_kind(name, registry), expected[name], name)
	registry.free()
