extends GutTest

## Playthroughs and what carries over (`Playthrough`, `InheritanceRule`): the
## core's rules, a new game that begins as the next playthrough, a legacy for
## a sequel, and the checks of a game's rules.

const LEGACY_PATH := "user://test_playthrough/legacy.json"

var _definition: GameDefinition
var _player: Dictionary
var _world: Dictionary
var _playthrough: int
var _legacy_path: String

func before_each() -> void:
	_definition = GameDefinition.current()
	_player = PlayerState.to_save_data()
	_world = WorldState.to_save_data()
	_playthrough = Playthrough.get_playthrough()
	_legacy_path = Playthrough.legacy_path
	Playthrough.legacy_path = LEGACY_PATH
	WorldState.clear()

func after_each() -> void:
	GameDefinition._current = _definition
	PlayerState.load_save_data(_player)
	WorldState.load_save_data(_world)
	Playthrough.call("_load_save_data", {"playthrough": _playthrough}, {})
	Playthrough.legacy_path = _legacy_path
	JsonFile.remove(LEGACY_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PATH.get_base_dir()))

func test_the_next_playthrough_begins_with_what_carries_over() -> void:
	var money := MoneyInheritance.new()
	money.percent = 50
	var world := WorldValueInheritance.new()
	world.prefixes = PackedStringArray(["legacy:"])
	_use_rules([money, world])
	PlayerState.money = 301
	WorldState.set_value(&"legacy:gate_open", true)
	WorldState.set_value(&"legacy:secrets", 3)
	WorldState.set_value(&"legacy:notes", {"kept": false})
	WorldState.set_value(&"farm:plot", true)
	var carried := Playthrough.capture()
	assert_eq(carried, {"money": 150, "world": {"legacy:gate_open": true, "legacy:secrets": 3}})

	# What the new game's step finds once the services are reset.
	PlayerState.money = 10
	WorldState.clear()
	watch_signals(Playthrough)
	Playthrough.set("_next", {"playthrough": 2, "carried": carried})
	Playthrough.call("_begin")
	assert_eq(Playthrough.get_playthrough(), 2, "known from the new game's first step")
	assert_eq(PlayerState.money, 10, "nothing carries over before the services are reset")
	Playthrough.call("_carry_over")
	assert_signal_emitted_with_parameters(Playthrough, "playthrough_started", [2])
	assert_eq(PlayerState.money, 160)
	assert_true(WorldState.get_bool(&"legacy:gate_open"))
	assert_eq(WorldState.get_int(&"legacy:secrets"), 3)
	assert_false(WorldState.has_value(&"farm:plot"))
	assert_true(GameRules.check("PLAYTHROUGH_AT_LEAST 2"))
	assert_false(GameRules.check("PLAYTHROUGH_AT_LEAST 3"))
	assert_eq(Playthrough.call("_to_save_data"), {"playthrough": 2})

	# A new game of its own is the first playthrough again.
	Playthrough.call("_begin")
	Playthrough.call("_carry_over")
	assert_eq(Playthrough.get_playthrough(), 1)
	assert_eq(PlayerState.money, 160)

func test_a_new_game_that_cannot_start_carries_nothing_over() -> void:
	WorldTravel.set("_traveling", true)
	var started := Playthrough.start_next()
	WorldTravel.set("_traveling", false)
	assert_false(started)
	assert_eq(Playthrough.get("_next"), {})
	assert_eq(Playthrough.get_playthrough(), _playthrough)

func test_rules_take_only_what_they_understand() -> void:
	var money := MoneyInheritance.new()
	var world := WorldValueInheritance.new()
	world.prefixes = PackedStringArray(["legacy:"])
	PlayerState.money = 5
	for bad: Variant in [-40, "lots", [1], null, 2.5]:
		money.apply(bad)
	assert_eq(PlayerState.money, 5)
	world.apply({"legacy:a": 1, "other:b": 2, "legacy:c": {"x": 1}})
	world.apply("not a dictionary")
	var keys := WorldState.get_keys("")
	assert_eq(keys.size(), 1)
	assert_eq(keys[0] if not keys.is_empty() else &"", &"legacy:a")

func test_a_legacy_carries_the_game_over_to_a_sequel() -> void:
	var money := MoneyInheritance.new()
	_use_rules([money])
	PlayerState.money = 77
	assert_true(Playthrough.write_legacy())
	var legacy := PlaythroughService.read_legacy(LEGACY_PATH)
	assert_eq(int(legacy["version"]), PlaythroughService.LEGACY_VERSION)
	assert_eq(String(legacy["game"]), String(ProjectSettings.get_setting("application/config/name")))
	assert_eq(int((legacy["carried"] as Dictionary)["money"]), 77)
	var file := FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": PlaythroughService.LEGACY_VERSION + 1, "carried": {}}))
	file.close()
	assert_eq(PlaythroughService.read_legacy(LEGACY_PATH), {}, "a legacy of another layout is not read")
	assert_eq(PlaythroughService.read_legacy("user://test_playthrough/none.json"), {})
	assert_eq(PlaythroughService.find_legacy("No Such Game Of GameBase"), {})
	# The engine's name for a game's user directory.
	assert_eq(PlaythroughService.user_directory_name(' Farm: "One"?<x>|a/b\\c. '), "Farm- -One---x--a-b-c")

func test_a_legacy_a_crash_kept_from_replacing_the_old_one_is_read() -> void:
	_use_rules([MoneyInheritance.new()])
	PlayerState.money = 12
	assert_true(Playthrough.write_legacy())
	assert_false(FileAccess.file_exists(LEGACY_PATH + ".tmp"), "the file is replaced whole")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(LEGACY_PATH), ProjectSettings.globalize_path(LEGACY_PATH + ".tmp"))
	assert_eq(int((PlaythroughService.read_legacy(LEGACY_PATH)["carried"] as Dictionary)["money"]), 12)

func test_a_game_s_rules_are_checked() -> void:
	var empty_world := WorldValueInheritance.new()
	empty_world.prefixes = PackedStringArray([""])
	var first := MoneyInheritance.new()
	var second := MoneyInheritance.new()
	var keyless := MoneyInheritance.new()
	keyless.key = &""
	var rules: Array[InheritanceRule] = [first, null, second, keyless, empty_world]
	assert_eq(InheritanceRule.find_list_problems(rules, ContentDB), PackedStringArray([
		"inheritance rule 2 is empty",
		"inheritance rules 1 and 3 share key 'money'",
		"inheritance rule 4 has no key",
		"inheritance rule 'world' has an empty prefix, which would carry the whole world",
	]))
	var plain: Array[InheritanceRule] = [MoneyInheritance.new()]
	assert_eq(InheritanceRule.find_list_problems(plain, ContentDB), PackedStringArray())

func test_a_save_holds_the_playthrough() -> void:
	Playthrough.call("_load_save_data", {"playthrough": 3.0}, {})
	assert_eq(Playthrough.get_playthrough(), 3)
	for bad: Variant in [0, -2, "x", 1.5]:
		Playthrough.call("_load_save_data", {"playthrough": bad}, {})
		assert_eq(Playthrough.get_playthrough(), 1, str(bad))

func _use_rules(rules: Array[InheritanceRule]) -> void:
	var definition := _definition.duplicate() as GameDefinition
	definition.inheritance = rules
	GameDefinition._current = definition
