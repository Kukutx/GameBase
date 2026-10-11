extends GutTest

## Triggers (`TriggerData`, `GameTriggerService`): content that runs actions
## when an autoload's signal fires and its condition holds.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

## Stands in for a module's `<Module>Events` autoload.
class FixtureEvents:
	extends Node
	signal harvested(quantity: int, crop: StringName)

var _events: FixtureEvents
var _world_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	WorldState.clear()
	_events = FixtureEvents.new()
	_events.name = "FixtureEvents"
	get_tree().root.add_child(_events)

func after_each() -> void:
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	_events.free()

func test_a_trigger_runs_its_actions_when_its_condition_holds() -> void:
	_start([_trigger(&"fixture_big_harvest", ["ADD_FLAG fixture:big_harvests"], "EVENT_ARG_AT_LEAST quantity 3, EVENT_ARG crop fixture_radish")])
	_events.harvested.emit(1, &"fixture_radish")
	_events.harvested.emit(5, &"fixture_gourd")
	assert_eq(WorldState.get_int(&"fixture:big_harvests"), 0)
	_events.harvested.emit(3, &"fixture_radish")
	assert_eq(WorldState.get_int(&"fixture:big_harvests"), 1)

func test_actions_repeat_per_unit_and_take_event_arguments() -> void:
	var per_crop := _trigger(&"fixture_per_crop", ["ADD_FLAG fixture:crops"])
	per_crop.repeat_per = &"quantity"
	_start([per_crop, _trigger(&"fixture_total", ["ADD_FLAG fixture:total $quantity"])])
	_events.harvested.emit(3, &"fixture_radish")
	_events.harvested.emit(0, &"fixture_radish")
	_events.harvested.emit(2, &"fixture_radish")
	assert_eq(WorldState.get_int(&"fixture:crops"), 5, "once per crop, none for none")
	assert_eq(WorldState.get_int(&"fixture:total"), 5)

func test_a_once_trigger_fires_once_per_world() -> void:
	var first := _trigger(&"fixture_first_harvest", ["ADD_FLAG fixture:first"])
	first.once = true
	var service := _start([first])
	watch_signals(service)
	_events.harvested.emit(1, &"fixture_radish")
	_events.harvested.emit(1, &"fixture_radish")
	assert_eq(WorldState.get_int(&"fixture:first"), 1)
	assert_true(service.has_fired(&"fixture_first_harvest"))
	assert_signal_emit_count(service, "trigger_fired", 1)
	WorldState.clear()
	_events.harvested.emit(1, &"fixture_radish")
	assert_eq(WorldState.get_int(&"fixture:first"), 1, "a new world fires it again")

func test_a_trigger_that_sets_itself_off_stops() -> void:
	var loop := _trigger(&"fixture_loop", ["ADD_FLAG fixture:loops"])
	loop.event = &"WorldState.changed"
	_start([loop])
	WorldState.set_value(&"fixture:start", true)
	assert_eq(WorldState.get_int(&"fixture:loops"), GameTriggerService.MAX_DEPTH)

func test_triggers_report_events_and_arguments_they_cannot_have() -> void:
	var unknown := _trigger(&"fixture_unknown_event", ["ADD_FLAG fixture:x"])
	unknown.event = &"FixtureEvents.grown"
	var idle := _trigger(&"fixture_idle", [])
	var per_crop_name := _trigger(&"fixture_per_name", ["ADD_FLAG fixture:x"])
	per_crop_name.repeat_per = &"crop"
	var missing := _trigger(&"fixture_missing", ["ADD_FLAG fixture:x $weight"], "EVENT_ARG season Spring")
	var registry := ContentFixture.use(self, [unknown, idle, per_crop_name, missing])
	var problems := "\n".join(registry.find_problems())
	assert_string_contains(problems, "trigger 'fixture_unknown_event' listens to 'FixtureEvents.grown', which is no signal of an autoload")
	assert_string_contains(problems, "trigger 'fixture_idle' has no actions")
	assert_string_contains(problems, "trigger 'fixture_per_name' repeats per 'crop', which is no integer argument")
	assert_string_contains(problems, "trigger 'fixture_missing' reads argument 'weight'")
	assert_string_contains(problems, "trigger 'fixture_missing' reads argument 'season'")

func test_only_triggers_name_event_arguments() -> void:
	var trigger := _trigger(&"fixture_total", ["ADD_FLAG fixture:total $quantity"])
	var minigame := MiniGameDefinition.new()
	minigame.id = &"fixture_minigame"
	minigame.success_actions = PackedStringArray(["ADD_MONEY $score"])
	var registry := ContentFixture.use(self, [trigger, minigame])
	var problems := "\n".join(GameRules.validate_content(registry))
	assert_false(problems.contains("fixture_total"), problems)
	assert_string_contains(problems, "minigame 'fixture_minigame' success_actions: only a trigger's conditions and actions name event arguments")

# Makes `triggers` the only content and starts a trigger service on them.
func _start(triggers: Array) -> GameTriggerService:
	ContentFixture.use(self, triggers)
	var service := GameTriggerService.new()
	add_child_autofree(service)
	return service

func _trigger(id: StringName, actions: Array, condition := "") -> TriggerData:
	var trigger := TriggerData.new()
	trigger.id = id
	trigger.event = &"FixtureEvents.harvested"
	trigger.condition = condition
	trigger.actions = PackedStringArray(actions)
	return trigger
