extends GutTest

const FLAG := &"test:rules_flag"
const COUNTER := &"test:rules_counter"

var _world_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

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
	assert_true(GameRules.check("DAY_AT_LEAST 30, SEASON Summer, DAY_OF_SEASON 2, WEEKDAY 1", {"day": 30}))
	assert_false(GameRules.check("SEASON Spring", {"day": 30}))
	assert_true(GameRules.check("TIME_BETWEEN 600 720", {"minute_of_day": 600}))
	assert_false(GameRules.check("TIME_BETWEEN 600 720", {"minute_of_day": 720}))

func test_actions_change_flags_counters_and_money() -> void:
	var money := PlayerState.money
	assert_true(GameRules.run_actions(PackedStringArray(["SET_FLAG %s" % FLAG, "ADD_FLAG %s 2" % COUNTER, "ADD_FLAG %s" % COUNTER, "ADD_MONEY 5"])))
	assert_true(WorldState.get_bool(FLAG))
	assert_eq(WorldState.get_int(COUNTER), 3)
	assert_true(GameRules.check("FLAG_AT_LEAST %s 3" % COUNTER))
	assert_eq(PlayerState.money, money + 5)
	assert_true(GameRules.run_actions(PackedStringArray(["CLEAR_FLAG %s" % FLAG])))
	assert_false(WorldState.get_bool(FLAG))

func test_module_keys_are_registered_and_checked_against_content() -> void:
	for key: String in ["HAS_ITEM", "QUEST_COMPLETED", "QUEST_ACTIVE", "SKILL_LEVEL", "HEARTS"]:
		assert_true(GameRules.has_condition(StringName(key)), key)
	for key: String in ["ADD_ITEM", "REMOVE_ITEM", "START_QUEST", "ADD_SKILL_XP", "ADD_FRIENDSHIP"]:
		assert_true(GameRules.has_action(StringName(key)), key)
	assert_eq(GameRules.validate_query("HAS_ITEM berry 2, !QUEST_COMPLETED first_harvest"), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("HAS_ITEM no_such_item, HEARTS mira lots, TYPO_KEY, WORLD_FLAG"))
	assert_string_contains(problems, "unknown item 'no_such_item'")
	assert_string_contains(problems, "'lots' is not an integer")
	assert_string_contains(problems, "unknown condition 'TYPO_KEY'")
	assert_string_contains(problems, "takes 1-2 arguments, got 0")
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["!ADD_MONEY 3"]))), "cannot be negated")

func test_module_argument_kinds_check_skills_and_levels() -> void:
	assert_eq(GameRules.validate_query("SKILL_LEVEL farming 10"), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("SKILL_LEVEL farming 11, SKILL_LEVEL cooking 2"))
	assert_string_contains(problems, "'11' is not a skill level (1-10)")
	assert_string_contains(problems, "unknown skill 'cooking'")
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["ADD_SKILL_XP sewing 5"]))), "unknown skill 'sewing'")

func test_describe_lists_what_a_condition_requires() -> void:
	assert_eq(GameRules.describe("SKILL_LEVEL mining 3, WORLD_FLAG %s, !SKILL_LEVEL farming 2" % FLAG), PackedStringArray(["Mining Lv3"]))
	assert_eq(GameRules.describe(""), PackedStringArray())
	assert_eq(GameRules.describe("NO_SUCH_KEY"), PackedStringArray())

func test_all_shipped_content_uses_registered_keys() -> void:
	assert_eq(GameRules.validate_content(ContentDB), PackedStringArray())

func test_content_validation_finds_conditions_in_nested_resources() -> void:
	var registry := ContentRegistry.new()
	autofree(registry)
	var entry := NpcScheduleEntry.new()
	entry.condition = "TYPO_KEY"
	var profile := NpcProfileData.new()
	profile.id = &"rules_test_npc"
	profile.schedule_entries = [entry]
	var mail := MailData.new()
	mail.id = &"rules_test_mail"
	mail.condition = "HAS_ITEM berry"
	registry.register_entries(&"npc", [profile], "npc", PackedStringArray())
	registry.register_entries(&"mail", [mail], "mail", PackedStringArray())
	var problems := GameRules.validate_content(registry)
	assert_eq(problems.size(), 1)
	assert_string_contains("\n".join(problems), "npc 'rules_test_npc' schedule_entries condition: unknown condition 'TYPO_KEY'")

func test_mail_condition_gates_delivery() -> void:
	var mail := MailData.new()
	mail.id = &"rules_test_mail"
	mail.condition = "WORLD_FLAG %s" % FLAG
	assert_false(mail.is_available(1))
	WorldState.set_value(FLAG, true)
	assert_true(mail.is_available(1))
