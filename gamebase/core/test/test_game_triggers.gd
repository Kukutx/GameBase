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

func test_a_once_trigger_whose_action_fails_resumes_at_that_action() -> void:
	# Succeeds only once the world allows it, as a reward needs inventory room.
	GameRules.register_action(&"FIXTURE_WHEN_ALLOWED", func(_args: PackedStringArray, _context: Dictionary) -> bool:
		return WorldState.get_bool(&"fixture:allowed"), 0, 0)
	var reward := _trigger(&"fixture_reward", ["ADD_FLAG fixture:given", "FIXTURE_WHEN_ALLOWED, ADD_FLAG fixture:after"])
	reward.once = true
	var service := _start([reward])
	watch_signals(service)
	_events.harvested.emit(1, &"fixture_radish")
	_events.harvested.emit(1, &"fixture_radish")
	assert_false(service.has_fired(&"fixture_reward"), "its action failed")
	assert_signal_not_emitted(service, "trigger_fired")
	assert_eq(WorldState.get_int(&"fixture:given"), 1, "what ran before the failed action is not given again")
	WorldState.set_value(&"fixture:allowed", true)
	_events.harvested.emit(1, &"fixture_radish")
	_events.harvested.emit(1, &"fixture_radish")
	assert_true(service.has_fired(&"fixture_reward"))
	assert_signal_emit_count(service, "trigger_fired", 1)
	assert_eq([WorldState.get_int(&"fixture:given"), WorldState.get_int(&"fixture:after")], [1, 1], "resumed at the failed action, then done")
	assert_false(WorldState.to_save_data().has("trigger:fixture_reward:progress"), "a fired trigger keeps no progress")
	GameRules._actions.erase(&"FIXTURE_WHEN_ALLOWED")

func test_a_loaded_world_keeps_only_what_current_once_triggers_fired() -> void:
	var first := _trigger(&"fixture_first_harvest", ["ADD_FLAG fixture:first"])
	first.once = true
	var second := _trigger(&"fixture_second_harvest", ["ADD_FLAG fixture:second"])
	second.once = true
	var every := _trigger(&"fixture_every_harvest", ["ADD_FLAG fixture:every"])
	var halfway := _trigger(&"fixture_halfway", ["ADD_FLAG fixture:a", "ADD_FLAG fixture:b", "ADD_FLAG fixture:c"])
	halfway.once = true
	_start([first, second, every, halfway])
	# A saved count comes back as a float.
	WorldState.load_save_data({"trigger:fixture_first_harvest:fired": true, "trigger:fixture_second_harvest:fired": 1,
		"trigger:fixture_every_harvest:fired": true, "trigger:fixture_removed:fired": true, "fixture:kept": 1,
		"trigger:fixture_halfway:progress": 2.0, "trigger:fixture_first_harvest:progress": 1, "trigger:fixture_second_harvest:progress": 9,
		"trigger:fixture_every_harvest:progress": 1})
	assert_eq(WorldState.to_save_data().keys(), ["trigger:fixture_first_harvest:fired", "fixture:kept", "trigger:fixture_halfway:progress"],
		"a fired mark is true and a count is short of all the actions of a once trigger that has not fired")

func test_what_a_restore_or_a_new_game_announces_fires_nothing() -> void:
	_start([_trigger(&"fixture_every_harvest", ["ADD_FLAG fixture:every"])])
	# The save manager and the session set these while they restore a save and
	# run the new-game steps.
	GameSaveManager._restoring = true
	_events.harvested.emit(1, &"fixture_radish")
	GameSaveManager._restoring = false
	GameSession._starting_new_game = true
	_events.harvested.emit(1, &"fixture_radish")
	GameSession._starting_new_game = false
	assert_eq(WorldState.get_int(&"fixture:every"), 0)
	_events.harvested.emit(1, &"fixture_radish")
	assert_eq(WorldState.get_int(&"fixture:every"), 1, "play fires it again")

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

func test_a_once_trigger_cannot_repeat() -> void:
	var repeated := _trigger(&"fixture_repeated_once", ["ADD_FLAG fixture:x"])
	repeated.once = true
	repeated.repeat_per = &"quantity"
	var problems := "\n".join(ContentFixture.use(self, [repeated]).find_problems())
	assert_string_contains(problems, "trigger 'fixture_repeated_once' fires once, so it cannot repeat per 'quantity'")

func test_a_check_of_arguments_together_runs_for_every_value_an_event_id_can_take() -> void:
	GameRules.register_condition(&"FIXTURE_AT_MOST", func(_args: PackedStringArray, _context: Dictionary) -> bool: return true,
		2, 2, [WorldLocationData.KIND, GameRulesService.ARG_INT], Callable(), _at_most_three)
	var never := _trigger(&"fixture_never", ["ADD_FLAG fixture:x"], "FIXTURE_AT_MOST $crop 99")
	var fine := _trigger(&"fixture_fine", ["ADD_FLAG fixture:x"], "FIXTURE_AT_MOST $crop 2")
	var registry := ContentFixture.use(self, [_location(&"fixture_field"), _location(&"fixture_barn"), never, fine])
	var problems := "\n".join(GameRules.validate_content(registry))
	assert_string_contains(problems, "condition 'FIXTURE_AT_MOST': 99 is more than 3, whatever the event's arguments are")
	assert_false(problems.contains("fixture_fine"), problems)
	GameRules._conditions.erase(&"FIXTURE_AT_MOST")

func test_an_event_value_is_checked_as_a_written_argument_is() -> void:
	GameRules.register_action(&"FIXTURE_VISIT", func(args: PackedStringArray, _context: Dictionary) -> bool:
		WorldState.add_int(StringName("fixture:visited:%s" % args[0]), 1)
		return true, 1, 1, [WorldLocationData.KIND])
	var visit := _trigger(&"fixture_visit", ["FIXTURE_VISIT $crop"])
	visit.once = true
	ContentFixture.use(self, [_location(&"fixture_field"), visit])
	var service := _service()
	_events.harvested.emit(1, &"fixture_nowhere")
	assert_false(service.has_fired(&"fixture_visit"), "an id the content does not have fails the action")
	assert_false(WorldState.to_save_data().has("fixture:visited:fixture_nowhere"))
	_events.harvested.emit(1, &"fixture_field")
	assert_true(service.has_fired(&"fixture_visit"))
	assert_eq(WorldState.get_int(&"fixture:visited:fixture_field"), 1)
	GameRules._actions.erase(&"FIXTURE_VISIT")

func test_triggers_report_arguments_of_the_wrong_type_and_inside_any() -> void:
	var wrong_type := _trigger(&"fixture_wrong_type", ["ADD_MONEY $crop"], "EVENT_ARG_AT_LEAST crop 3")
	var nested := _trigger(&"fixture_nested", ["ADD_FLAG fixture:x"], 'ANY "EVENT_ARG season Spring" "FALSE"')
	var fine := _trigger(&"fixture_fine", ["ADD_MONEY $quantity", "SET_FLAG $crop"], "EVENT_ARG_AT_LEAST quantity 1")
	var registry := ContentFixture.use(self, [wrong_type, nested, fine])
	var problems := "\n".join(registry.find_problems())
	assert_string_contains(problems, "trigger 'fixture_wrong_type' passes argument 'crop' (StringName) to ADD_MONEY, which takes int")
	assert_string_contains(problems, "trigger 'fixture_wrong_type' passes argument 'crop' (StringName) to EVENT_ARG_AT_LEAST, which takes number")
	assert_string_contains(problems, "trigger 'fixture_nested' reads argument 'season'")
	assert_false(problems.contains("fixture_fine"), problems)

func test_only_triggers_name_event_arguments() -> void:
	var trigger := _trigger(&"fixture_total", ["ADD_FLAG fixture:total $quantity"])
	var minigame := MiniGameDefinition.new()
	minigame.id = &"fixture_minigame"
	minigame.success_actions = PackedStringArray(["ADD_MONEY $score"])
	var registry := ContentFixture.use(self, [trigger, minigame])
	var problems := "\n".join(GameRules.validate_content(registry))
	assert_false(problems.contains("fixture_total"), problems)
	assert_string_contains(problems, "minigame 'fixture_minigame' success_actions: only a trigger's conditions and actions name event arguments")
	var nested := GameRulesService.find_event_arg_uses(PackedStringArray(['ANY "EVENT_ARG crop fixture_radish" "WORLD_FLAG $crop"']))
	assert_eq(nested.size(), 2, "the clauses inside ANY name event arguments too")

# Makes `triggers` the only content and starts a trigger service on them.
func _start(triggers: Array) -> GameTriggerService:
	ContentFixture.use(self, triggers)
	return _service()

# A trigger service on the active content.
func _service() -> GameTriggerService:
	var service := GameTriggerService.new()
	add_child_autofree(service)
	return service

func _location(id: StringName) -> WorldLocationData:
	var location := WorldLocationData.new()
	location.id = id
	return location

# The arguments-together check of FIXTURE_AT_MOST <location> <count>.
static func _at_most_three(args: PackedStringArray) -> String:
	return "" if int(args[1]) <= 3 else "%s is more than 3" % args[1]

func _trigger(id: StringName, actions: Array, condition := "") -> TriggerData:
	var trigger := TriggerData.new()
	trigger.id = id
	trigger.event = &"FixtureEvents.harvested"
	trigger.condition = condition
	trigger.actions = PackedStringArray(actions)
	return trigger
