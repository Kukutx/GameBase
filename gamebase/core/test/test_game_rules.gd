extends GutTest

## The core's own condition and action keys and the query syntax. Each
## module's keys are tested with the module (`test_*_rules.gd`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

const FLAG := &"test:rules_flag"
const COUNTER := &"test:rules_counter"

var _world_snapshot: Dictionary
var _vitals_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()

func after_each() -> void:
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	Vitals.load_save_data(_vitals_snapshot)

func test_query_syntax_parses_negation_quotes_and_any() -> void:
	var parsed := GameQuery.parse('WORLD_flag a:b, !SEASON Spring Summer, ANY "DAY_AT_LEAST 3, TRUE" "FALSE"')
	assert_eq(String(parsed["error"]), "")
	var clauses: Array = parsed["clauses"]
	assert_eq(clauses.size(), 3)
	assert_eq(clauses[0]["key"], &"WORLD_FLAG")
	assert_eq(clauses[0]["args"], PackedStringArray(["a:b"]))
	assert_true(bool(clauses[1]["negate"]))
	assert_eq(clauses[2]["args"], PackedStringArray(["DAY_AT_LEAST 3, TRUE", "FALSE"]))
	assert_string_contains(String(GameQuery.parse('WORLD_FLAG "open').get("error")), "unterminated quote")
	assert_string_contains(String(GameQuery.parse("TRUE,,FALSE").get("error")), "empty clause")

func test_conditions_combine_with_and_not_and_any() -> void:
	WorldState.set_value(FLAG, true)
	assert_true(GameRules.check(""))
	assert_true(GameRules.check("WORLD_FLAG %s" % FLAG))
	assert_false(GameRules.check("!WORLD_FLAG %s" % FLAG))
	assert_true(GameRules.check("WORLD_FLAG %s false, TRUE" % COUNTER))
	assert_true(GameRules.check('ANY "FALSE" "WORLD_FLAG %s"' % FLAG))
	assert_false(GameRules.check('ANY "FALSE" "!TRUE"'))
	assert_false(GameRules.check("NO_SUCH_KEY"), "unknown keys never match")

func test_time_conditions_read_the_day_from_the_context() -> void:
	ContentFixture.use_calendar(self, GameCalendar.new())
	assert_true(GameRules.check("DAY_AT_LEAST 30, SEASON Summer, DAY_OF_SEASON 2, WEEKDAY 1", {"day": 30}))
	assert_false(GameRules.check("SEASON Spring", {"day": 30}))
	assert_true(GameRules.check("TIME_BETWEEN 600 720", {"minute_of_day": 600}))
	assert_false(GameRules.check("TIME_BETWEEN 600 720", {"minute_of_day": 720}))

func test_actions_change_flags_and_counters() -> void:
	assert_true(GameRules.run_actions(PackedStringArray(["SET_FLAG %s" % FLAG, "ADD_FLAG %s 2" % COUNTER, "ADD_FLAG %s" % COUNTER])))
	assert_true(WorldState.get_bool(FLAG))
	assert_eq(WorldState.get_int(COUNTER), 3)
	assert_true(GameRules.check("FLAG_AT_LEAST %s 3" % COUNTER))
	assert_true(GameRules.run_actions(PackedStringArray(["CLEAR_FLAG %s" % FLAG])))
	assert_false(WorldState.get_bool(FLAG))

func test_vital_conditions_and_actions_read_and_restore_a_vital() -> void:
	var stamina := VitalData.new()
	stamina.id = &"fixture_stamina"
	stamina.display_name = "Stamina"
	stamina.maximum = 40
	ContentFixture.use(self, [stamina])
	Vitals.reset_new_game()
	assert_true(Vitals.spend(stamina.id, 30))
	assert_true(GameRules.check("VITAL_AT_LEAST fixture_stamina 10"))
	assert_false(GameRules.check("VITAL_AT_LEAST fixture_stamina 11"))
	assert_true(GameRules.run_actions(PackedStringArray(["RESTORE_VITAL fixture_stamina 25"])))
	assert_eq(Vitals.get_value(stamina.id), 35)
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["RESTORE_VITAL fixture_mana 5"]))), "fixture_mana")

func test_an_action_list_that_cannot_run_as_written_runs_none() -> void:
	# An unterminated quote parses to no clause, as many as an empty list has.
	assert_eq(GameRules.run_actions_from(PackedStringArray(['ADD_FLAG %s "5' % COUNTER]), 0), -1)
	assert_false(GameRules.run_actions(PackedStringArray(["ADD_FLAG %s 5" % COUNTER, 'ADD_FLAG %s "5' % COUNTER])))
	assert_false(GameRules.can_run_actions_from(PackedStringArray(['ADD_FLAG %s "5' % COUNTER]), 0))
	assert_push_warning_count(3)
	assert_eq(WorldState.get_int(COUNTER), 0, "not even the actions before it")
	assert_true(GameRules.can_run_actions_from(PackedStringArray(["ADD_FLAG %s 5" % COUNTER]), 0))
	assert_eq(WorldState.get_int(COUNTER), 0, "asking runs nothing")

func test_validation_reports_unknown_keys_argument_counts_kinds_and_negated_actions() -> void:
	for key: String in ["TRUE", "WORLD_FLAG", "SEASON", "LOCATION", "VITAL_AT_LEAST"]:
		assert_true(GameRules.has_condition(StringName(key)), key)
	for key: String in ["SET_FLAG", "CLEAR_FLAG", "ADD_FLAG", "RESTORE_VITAL"]:
		assert_true(GameRules.has_action(StringName(key)), key)
	assert_eq(GameRules.validate_query("WORLD_FLAG %s, !DAY_AT_LEAST 3" % FLAG), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("FLAG_AT_LEAST %s lots, TYPO_KEY, WORLD_FLAG" % COUNTER))
	assert_string_contains(problems, "'lots' is not an integer")
	assert_string_contains(problems, "unknown condition 'TYPO_KEY'")
	assert_string_contains(problems, "takes 1-2 arguments, got 0")
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["!ADD_FLAG %s 3" % COUNTER]))), "cannot be negated")
	assert_eq(GameRules.validate_actions(PackedStringArray(["SET_FLAG %s false, SET_FLAG %s 3" % [FLAG, COUNTER]])), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["SET_FLAG %s ture" % FLAG]))), "'ture' is not true, false or an integer")

func test_content_arguments_are_checked_against_the_running_game_content() -> void:
	var location := WorldLocationData.new()
	location.id = &"fixture_meadow"
	ContentFixture.use(self, [location])
	assert_eq(GameRules.validate_query("LOCATION fixture_meadow"), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_query("LOCATION fixture_meadow no_such_place")), "unknown location 'no_such_place'")

func test_a_condition_can_check_its_arguments_together() -> void:
	var rules := GameRulesService.new()
	autofree(rules)
	var evaluate := func(_args: PackedStringArray, _context: Dictionary) -> bool: return true
	var ordered := func(args: PackedStringArray) -> String:
		return "" if int(args[0]) <= int(args[1]) else "%s is above %s" % [args[0], args[1]]
	rules.register_condition(&"BETWEEN", evaluate, 2, 2, [GameRulesService.ARG_INT], Callable(), ordered)
	assert_eq(rules.validate_query("BETWEEN 1 2"), PackedStringArray())
	assert_eq(rules.validate_query("BETWEEN 3 2"), PackedStringArray(["condition 'BETWEEN': 3 is above 2"]))
	assert_eq(rules.validate_query("BETWEEN x 2"), PackedStringArray(["condition 'BETWEEN' argument 1: 'x' is not an integer"]),
		"the arguments are checked together only once each passed")

func test_describe_leaves_out_conditions_without_a_description() -> void:
	assert_eq(GameRules.describe("WORLD_FLAG %s, DAY_AT_LEAST 2" % FLAG), PackedStringArray())
	assert_eq(GameRules.describe(""), PackedStringArray())
	assert_eq(GameRules.describe("NO_SUCH_KEY"), PackedStringArray())
