extends GutTest

## Triggers (`TriggerData`, `GameTriggerService`): content that runs actions
## when an autoload's signal fires and its condition holds.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

## Stands in for a module's `<Module>Events` autoload.
class FixtureEvents:
	extends Node
	signal harvested(quantity: int, crop: StringName)
	signal found(item: Resource)

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
	assert_true(service.is_pending(&"fixture_reward"))
	assert_signal_not_emitted(service, "trigger_fired")
	assert_eq(WorldState.get_int(&"fixture:given"), 1, "what ran before the failed action is not given again")
	WorldState.set_value(&"fixture:allowed", true)
	_events.harvested.emit(1, &"fixture_radish")
	_events.harvested.emit(1, &"fixture_radish")
	assert_true(service.has_fired(&"fixture_reward"))
	assert_signal_emit_count(service, "trigger_fired", 1)
	assert_eq([WorldState.get_int(&"fixture:given"), WorldState.get_int(&"fixture:after")], [1, 1], "resumed at the failed action, then done")
	assert_false(service.is_pending(&"fixture_reward"), "a fired trigger is not pending")
	GameRules._actions.erase(&"FIXTURE_WHEN_ALLOWED")

func test_a_pending_trigger_resumes_with_the_event_that_set_it_off_and_without_its_condition() -> void:
	GameRules.register_action(&"FIXTURE_WHEN_ALLOWED", func(_args: PackedStringArray, _context: Dictionary) -> bool:
		return WorldState.get_bool(&"fixture:allowed"), 0, 0)
	# Its first action makes its own condition false.
	var reward := _trigger(&"fixture_pending", ["CLEAR_FLAG fixture:open", "FIXTURE_WHEN_ALLOWED", "ADD_FLAG fixture:quantity $quantity"], "WORLD_FLAG fixture:open")
	reward.once = true
	var service := _start([reward])
	WorldState.set_value(&"fixture:open", true)
	_events.harvested.emit(3, &"fixture_radish")
	assert_true(service.is_pending(&"fixture_pending"))
	WorldState.set_value(&"fixture:allowed", true)
	_events.harvested.emit(7, &"fixture_radish")
	assert_true(service.has_fired(&"fixture_pending"), "it resumed though its condition no longer holds")
	assert_eq(WorldState.get_int(&"fixture:quantity"), 3, "with the arguments of the event that set it off")
	GameRules._actions.erase(&"FIXTURE_WHEN_ALLOWED")

func test_a_pending_trigger_resumes_through_a_save_with_the_event_s_values_in_their_types() -> void:
	var seen := []
	# Records what it is given, and succeeds once the world allows it.
	GameRules.register_action(&"FIXTURE_RECORD", func(_args: PackedStringArray, context: Dictionary) -> bool:
		seen.append(context["event"].duplicate())
		return WorldState.get_bool(&"fixture:allowed"), 0, 0)
	var reward := _trigger(&"fixture_record", ["ADD_FLAG fixture:before", "FIXTURE_RECORD"])
	reward.once = true
	var service := _start([reward])
	_events.harvested.emit(3, &"fixture_radish")
	assert_true(service.is_pending(&"fixture_record"))
	# Saved and loaded as JSON.
	WorldState.load_save_data(JSON.parse_string(JSON.stringify(WorldState.to_save_data())))
	WorldState.set_value(&"fixture:allowed", true)
	_events.harvested.emit(7, &"fixture_gourd")
	assert_true(service.has_fired(&"fixture_record"))
	assert_eq(seen.size(), 2)
	assert_eq(seen[1], {"quantity": 3, "crop": &"fixture_radish"})
	assert_eq([typeof(seen[1]["quantity"]), typeof(seen[1]["crop"])], [TYPE_INT, TYPE_STRING_NAME], "as the event gave them")
	GameRules._actions.erase(&"FIXTURE_RECORD")

func test_a_pending_trigger_whose_actions_changed_fires_anew() -> void:
	GameRules.register_action(&"FIXTURE_WHEN_ALLOWED", func(_args: PackedStringArray, _context: Dictionary) -> bool:
		return WorldState.get_bool(&"fixture:allowed"), 0, 0)
	var reward := _trigger(&"fixture_reward", ["ADD_FLAG fixture:given", "FIXTURE_WHEN_ALLOWED"])
	reward.once = true
	var service := _start([reward])
	_events.harvested.emit(1, &"fixture_radish")
	assert_true(service.is_pending(&"fixture_reward"))
	# A content update puts a new reward where the trigger stopped.
	reward.actions = PackedStringArray(["ADD_FLAG fixture:given", "ADD_FLAG fixture:new", "FIXTURE_WHEN_ALLOWED"])
	assert_false(service.is_pending(&"fixture_reward"), "where it stopped no longer means the same")
	WorldState.load_save_data(WorldState.to_save_data())
	assert_null(WorldState.get_value(GameTriggerService.STATE_KEY), "a loaded world drops it")
	WorldState.set_value(&"fixture:allowed", true)
	_events.harvested.emit(1, &"fixture_radish")
	assert_true(service.has_fired(&"fixture_reward"))
	assert_eq([WorldState.get_int(&"fixture:given"), WorldState.get_int(&"fixture:new")], [2, 1], "it ran its actions as they are now")
	GameRules._actions.erase(&"FIXTURE_WHEN_ALLOWED")

func test_a_loaded_world_keeps_only_what_current_once_triggers_left() -> void:
	var first := _trigger(&"fixture_first_harvest", ["ADD_FLAG fixture:first"])
	first.once = true
	var second := _trigger(&"fixture_second_harvest", ["ADD_FLAG fixture:second", "ADD_FLAG fixture:second"])
	second.once = true
	var every := _trigger(&"fixture_every_harvest", ["ADD_FLAG fixture:every"])
	var halfway := _trigger(&"fixture_halfway", ["ADD_FLAG fixture:a", "ADD_FLAG fixture:b", "ADD_FLAG fixture:c"])
	halfway.once = true
	_start([first, second, every, halfway])
	# As JSON gives a save back: every number a float.
	var event := {"quantity": {"type": float(TYPE_INT), "value": 1.0}, "crop": {"type": float(TYPE_STRING_NAME), "value": "fixture_radish"}}
	var halfway_actions := GameTriggerService.get_actions_fingerprint(halfway)
	var pending := func(trigger: TriggerData, done: Variant, values: Dictionary) -> Dictionary:
		return {"done": done, "actions": GameTriggerService.get_actions_fingerprint(trigger), "event": values}
	WorldState.load_save_data({"fixture:kept": 1, GameTriggerService.STATE_KEY: {
		"fired": ["fixture_first_harvest", "fixture_every_harvest", "fixture_removed", 3, "fixture_first_harvest"],
		"pending": {
			"fixture_halfway": pending.call(halfway, 2.0, event),
			"fixture_first_harvest": pending.call(first, 1.0, event),
			"fixture_every_harvest": pending.call(every, 1.0, event),
			"fixture_removed": {"done": 1.0, "actions": halfway_actions, "event": event},
			"fixture_second_harvest": pending.call(second, 1.0, {"quantity": event["quantity"]}),
		}}})
	var kept := {"quantity": {"type": TYPE_INT, "value": 1}, "crop": {"type": TYPE_STRING_NAME, "value": "fixture_radish"}}
	assert_eq(WorldState.get_value(GameTriggerService.STATE_KEY), {"fired": ["fixture_first_harvest"], "pending": {"fixture_halfway": {"done": 2, "actions": halfway_actions, "event": kept}}},
		"what current once triggers fired, and where one that has not can resume with every argument of its event")
	assert_eq(WorldState.get_int(&"fixture:kept"), 1)
	for done: Variant in [0, 3, 1.5]:
		WorldState.load_save_data({GameTriggerService.STATE_KEY: {"fired": [], "pending": {"fixture_halfway": pending.call(halfway, done, event)}}})
		assert_null(WorldState.get_value(GameTriggerService.STATE_KEY), "%s actions done is not where it can resume" % done)
	var malformed := [
		{"quantity": "1", "crop": "fixture_radish"},
		{"quantity": {"type": float(TYPE_INT), "value": 1.5}, "crop": event["crop"]},
		{"quantity": {"type": float(TYPE_OBJECT), "value": 1.0}, "crop": event["crop"]},
		{"quantity": event["quantity"], "crop": {"type": float(TYPE_STRING_NAME), "value": 4.0}},
	]
	for values: Dictionary in malformed:
		WorldState.load_save_data({GameTriggerService.STATE_KEY: {"fired": [], "pending": {"fixture_halfway": pending.call(halfway, 1.0, values)}}})
		assert_null(WorldState.get_value(GameTriggerService.STATE_KEY), "%s is no event value a save keeps" % values)
	WorldState.load_save_data({GameTriggerService.STATE_KEY: true})
	assert_null(WorldState.get_value(GameTriggerService.STATE_KEY))

func test_a_loaded_world_drops_a_pending_trigger_whose_saved_value_is_no_longer_content() -> void:
	GameRules.register_action(&"FIXTURE_VISIT", func(_args: PackedStringArray, _context: Dictionary) -> bool: return true,
		1, 1, [WorldLocationData.KIND])
	var visit := _trigger(&"fixture_visit", ["ADD_FLAG fixture:before", "FIXTURE_VISIT $crop"])
	visit.once = true
	var service := _start([_location(&"fixture_field"), visit])
	for crop: String in ["fixture_field", "fixture_removed"]:
		var event := {"quantity": {"type": float(TYPE_INT), "value": 1.0}, "crop": {"type": float(TYPE_STRING_NAME), "value": crop}}
		var pending := {"fixture_visit": {"done": 1.0, "actions": GameTriggerService.get_actions_fingerprint(visit), "event": event}}
		WorldState.load_save_data({GameTriggerService.STATE_KEY: {"fired": [], "pending": pending}})
		assert_eq(service.is_pending(&"fixture_visit"), crop == "fixture_field", crop)
	GameRules._actions.erase(&"FIXTURE_VISIT")

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

func test_an_event_value_that_fails_its_check_fails_the_condition_whatever_surrounds_it() -> void:
	var away := _trigger(&"fixture_away", ["ADD_FLAG fixture:away"], "!LOCATION $crop")
	var any_away := _trigger(&"fixture_any_away", ["ADD_FLAG fixture:any_away"], '!ANY "LOCATION $crop" "FALSE"')
	# A branch or a clause that decides the result before it does not hide it.
	var any_first := _trigger(&"fixture_any_first", ["ADD_FLAG fixture:any_first"], 'ANY "TRUE" "LOCATION $crop"')
	var false_first := _trigger(&"fixture_false_first", ["ADD_FLAG fixture:false_first"], '!ANY "FALSE, LOCATION $crop" "FALSE"')
	ContentFixture.use(self, [_location(&"fixture_field"), away, any_away, any_first, false_first])
	_service()
	var counts := func() -> Array:
		return [&"fixture:away", &"fixture:any_away", &"fixture:any_first", &"fixture:false_first"].map(WorldState.get_int)
	_events.harvested.emit(1, &"fixture_nowhere")
	assert_eq(counts.call(), [0, 0, 0, 0], "an id the content does not have")
	_events.harvested.emit(1, &"fixture_field")
	assert_eq(counts.call(), [1, 1, 1, 1], "the player is not in the field")

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
	var blank := _trigger(&"fixture_blank", ["", " "])
	var per_crop_name := _trigger(&"fixture_per_name", ["ADD_FLAG fixture:x"])
	per_crop_name.repeat_per = &"crop"
	var missing := _trigger(&"fixture_missing", ["ADD_FLAG fixture:x $weight"], "EVENT_ARG season Spring")
	var registry := ContentFixture.use(self, [unknown, idle, blank, per_crop_name, missing])
	var problems := "\n".join(registry.find_problems())
	assert_string_contains(problems, "trigger 'fixture_unknown_event' listens to 'FixtureEvents.grown', which is no signal of an autoload")
	assert_string_contains(problems, "trigger 'fixture_idle' has no actions")
	assert_string_contains(problems, "trigger 'fixture_blank' has no actions")
	assert_string_contains(problems, "trigger 'fixture_per_name' repeats per 'crop', which is no integer argument")
	assert_string_contains(problems, "trigger 'fixture_missing' reads argument 'weight'")
	assert_string_contains(problems, "trigger 'fixture_missing' reads argument 'season'")

func test_a_once_trigger_cannot_repeat_nor_listen_to_what_a_save_cannot_keep() -> void:
	var repeated := _trigger(&"fixture_repeated_once", ["ADD_FLAG fixture:x"])
	repeated.once = true
	repeated.repeat_per = &"quantity"
	var found := _trigger(&"fixture_found_once", ["ADD_FLAG fixture:x"])
	found.event = &"FixtureEvents.found"
	found.once = true
	var found_every := _trigger(&"fixture_found_every", ["ADD_FLAG fixture:x"])
	found_every.event = &"FixtureEvents.found"
	var problems := "\n".join(ContentFixture.use(self, [repeated, found, found_every]).find_problems())
	assert_string_contains(problems, "trigger 'fixture_repeated_once' fires once, so it cannot repeat per 'quantity'")
	assert_string_contains(problems, "trigger 'fixture_found_once' fires once, so a save may keep its event's arguments, and 'item' is of type Object")
	assert_false(problems.contains("fixture_found_every"), problems)

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
	var visit := _trigger(&"fixture_visit", ["ADD_FLAG fixture:before", "FIXTURE_VISIT $crop"])
	visit.once = true
	ContentFixture.use(self, [_location(&"fixture_field"), visit])
	var service := _service()
	_events.harvested.emit(1, &"fixture_nowhere")
	assert_false(service.has_fired(&"fixture_visit"), "an id the content does not have fails the action")
	assert_false(WorldState.to_save_data().has("fixture:visited:fixture_nowhere"))
	assert_eq(WorldState.get_int(&"fixture:before"), 0, "no action runs when one cannot")
	assert_false(service.is_pending(&"fixture_visit"), "it gave nothing, so it fires anew")
	_events.harvested.emit(1, &"fixture_field")
	assert_true(service.has_fired(&"fixture_visit"))
	assert_eq([WorldState.get_int(&"fixture:before"), WorldState.get_int(&"fixture:visited:fixture_field")], [1, 1])
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
