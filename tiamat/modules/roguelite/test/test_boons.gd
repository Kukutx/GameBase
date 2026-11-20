extends GutTest

## Boons (`BoonData`): what a run offers, what taking one does, the stats it
## changes until the run ends, its rule keys and the altar the player takes
## one at.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const ALTAR_SCENE := preload("res://tiamat/modules/roguelite/runs/boon_altar.tscn")
const COUNTER := &"test:boon_counter"
const SPEED := TopDownPlayer.MOVE_SPEED_STAT

var _world: Dictionary

func before_each() -> void:
	_world = WorldState.to_save_data()
	WorldState.clear()
	ContentFixture.use(self, [
		_boon(&"fixture_swift", "Swift", {SPEED: 1.5}, {}, 2),
		_boon(&"fixture_sturdy", "Sturdy", {}, {SPEED: 10.0}),
		_boon(&"fixture_lucky", "Lucky", {}, {}, 99, PackedStringArray(["ADD_FLAG %s 2" % COUNTER])),
		_boon(&"fixture_gated", "Gated", {SPEED: 2.0}, {}, 1, PackedStringArray(), "WORLD_FLAG test:boon_gate"),
	])

func after_each() -> void:
	InputLock.clear()
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world)

func _boon(boon_id: StringName, boon_name: String, multipliers: Dictionary, bonuses: Dictionary, stacks := 1, actions := PackedStringArray(), condition := "") -> BoonData:
	var boon := BoonData.new()
	boon.id = boon_id
	boon.display_name = boon_name
	boon.description = "%s boon" % boon_name
	boon.multipliers.assign(multipliers)
	boon.bonuses.assign(bonuses)
	boon.max_stacks = stacks
	boon.actions = actions
	boon.condition = condition
	return boon

func _ids(boons: Array[BoonData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for boon: BoonData in boons:
		ids.append(boon.id)
	return ids

func test_a_run_offers_the_boons_it_may_take_each_once_the_same_each_time() -> void:
	assert_eq(RunState.offer_boons(3, "first"), [] as Array[BoonData], "no run, no boons")
	RunState.start_run()
	var offer := _ids(RunState.offer_boons(3, "first"))
	assert_eq(offer.size(), 3)
	assert_false(offer.has(&"fixture_gated"), "a boon whose condition does not hold")
	for boon_id: StringName in offer:
		assert_eq(offer.count(boon_id), 1, "none twice")
	assert_eq(_ids(RunState.offer_boons(3, "first")), offer, "the same run and name offer the same")
	assert_eq(RunState.offer_boons(9, "second").size(), 3, "as many as the run may take")
	assert_true(RunState.take_boon(&"fixture_sturdy"))
	assert_false(_ids(RunState.offer_boons(3, "third")).has(&"fixture_sturdy"), "a boon taken as often as it may be")
	WorldState.set_value(&"test:boon_gate", true)
	assert_true(_ids(RunState.offer_boons(9, "fourth")).has(&"fixture_gated"))

func test_a_boon_changes_stats_once_more_each_time_taken_until_the_run_ends() -> void:
	assert_false(RunState.take_boon(&"fixture_swift"), "no run")
	RunState.start_run()
	# What other sources (a skill's perk) give the stat stays as it is.
	var base := GameStats.get_multiplier(SPEED)
	var bonus := GameStats.get_bonus(SPEED)
	watch_signals(RunState)
	assert_true(RunState.take_boon(&"fixture_swift"))
	assert_signal_emitted_with_parameters(RunState, "boon_taken", [&"fixture_swift"])
	assert_almost_eq(GameStats.get_multiplier(SPEED), base * 1.5, 0.001)
	assert_true(RunState.take_boon(&"fixture_swift"))
	assert_false(RunState.take_boon(&"fixture_swift"), "taken as often as it may be")
	assert_eq(RunState.get_boon_stacks(&"fixture_swift"), 2)
	assert_almost_eq(GameStats.get_multiplier(SPEED), base * 2.25, 0.001)
	assert_true(RunState.take_boon(&"fixture_sturdy"))
	assert_almost_eq(GameStats.get_bonus(SPEED), bonus + 10.0, 0.001)
	assert_eq(RunState.get_boons(), [&"fixture_sturdy", &"fixture_swift"] as Array[StringName])
	RunState.end_run(RunService.OUTCOME_RETURNED)
	assert_almost_eq(GameStats.get_multiplier(SPEED), base, 0.001, "the run's boons end with it")
	assert_almost_eq(GameStats.get_bonus(SPEED), bonus, 0.001)
	assert_eq(RunState.get_boons(), [] as Array[StringName])

func test_an_altar_offers_the_boons_of_its_pool() -> void:
	var pact := _boon(&"fixture_pact", "Pact", {SPEED: 0.5}, {})
	pact.pool = &"fixture_pacts"
	ContentFixture.use(self, [_boon(&"fixture_swift", "Swift", {SPEED: 1.5}, {}), pact])
	RunState.start_run()
	assert_eq(RunState.offer_boons(3, "common").map(func(boon: BoonData) -> StringName: return boon.id), [&"fixture_swift"])
	assert_eq(RunState.offer_boons(3, "pacts", &"fixture_pacts").map(func(boon: BoonData) -> StringName: return boon.id), [&"fixture_pact"])
	assert_eq(BoonData.find_pool(&"fixture_pacts"), [pact] as Array[BoonData])
	var altar := ALTAR_SCENE.instantiate() as BoonAltar
	altar.pool = &"fixture_pacts"
	add_child_autofree(altar)
	assert_eq(altar.get_offer(), [pact] as Array[BoonData])

func test_a_boon_acts_each_time_it_is_taken() -> void:
	RunState.start_run()
	assert_true(RunState.take_boon(&"fixture_lucky"))
	assert_true(RunState.take_boon(&"fixture_lucky"))
	assert_eq(WorldState.get_int(COUNTER), 4)
	assert_false(RunState.take_boon(&"fixture_gated"), "its condition does not hold")
	assert_false(RunState.take_boon(&"fixture_none"))

func test_content_gives_a_boon_and_asks_whether_the_run_took_one() -> void:
	RunState.start_run()
	assert_false(GameRules.check("BOON_TAKEN fixture_swift"))
	assert_true(GameRules.run_actions(PackedStringArray(["TAKE_BOON fixture_swift"])))
	assert_true(GameRules.check("BOON_TAKEN fixture_swift"))
	assert_false(GameRules.check("BOON_TAKEN fixture_swift fixture_sturdy"), "each must be taken")
	assert_eq(GameRules.describe("BOON_TAKEN fixture_swift"), PackedStringArray(["With Swift"]))
	assert_eq(GameRules.validate_query("BOON_TAKEN fixture_no_such_boon").size(), 1)

func test_an_altar_gives_one_boon_a_run_from_its_own_offer() -> void:
	RunState.start_run()
	var altar := ALTAR_SCENE.instantiate() as BoonAltar
	altar.key = "depth3"
	add_child_autofree(altar)
	assert_true(altar.interactable.enabled)
	var offer := _ids(altar.get_offer())
	assert_eq(offer, _ids(RunState.offer_boons(3, "depth3")), "the altar's offer is the run's under its key")
	var outcome := {}
	(func() -> void: outcome["boon"] = await altar.choose()).call()
	var menu := ChoiceMenu.of(altar)
	assert_eq((menu.get_node("%Title") as Label).text, "Choose a Boon")
	assert_eq(menu.get_buttons().size(), 3)
	assert_true(menu.choose(offer[0]))
	assert_eq(outcome.get("boon"), offer[0])
	assert_eq(RunState.get_boon_stacks(offer[0]), 1)
	assert_true(altar.is_spent())
	assert_false(altar.interactable.enabled, "spent")
	assert_eq(altar.get_offer(), [] as Array[BoonData])
	RunState.start_run()
	assert_false(altar.is_spent(), "a new run lights it again")

func test_a_boon_on_offer_says_how_often_the_run_took_it() -> void:
	RunState.start_run()
	var swift := BoonData.find(&"fixture_swift")
	assert_eq(BoonAltar.choice_of(swift).text, "Swift")
	assert_eq(BoonAltar.choice_of(swift).note, "Swift boon", "not before the run took it")
	RunState.take_boon(&"fixture_swift")
	assert_eq(BoonAltar.choice_of(swift).note, "Swift boon\nTaken 1 of 2")
	RunState.take_boon(&"fixture_lucky")
	assert_eq(BoonAltar.choice_of(BoonData.find(&"fixture_lucky")).note, "Lucky boon\nTaken 1", "one it may take as often as offered")

func test_the_hud_tells_the_run_s_boons() -> void:
	var line := BoonLine.new()
	add_child_autofree(line)
	await get_tree().process_frame
	assert_false(line.visible, "no run, no line")
	RunState.start_run()
	RunState.take_boon(&"fixture_swift")
	RunState.take_boon(&"fixture_swift")
	RunState.take_boon(&"fixture_sturdy")
	assert_eq(RunState.describe_boons(), PackedStringArray(["Sturdy", "Swift ×2"]))
	await get_tree().process_frame
	assert_true(line.visible)
	assert_eq(line.text, "Sturdy · Swift ×2")
	RunState.end_run(RunService.OUTCOME_RETURNED)
	await get_tree().process_frame
	assert_false(line.visible, "the boons end with the run")

func test_closing_the_altar_s_list_takes_nothing() -> void:
	RunState.start_run()
	var altar := ALTAR_SCENE.instantiate() as BoonAltar
	add_child_autofree(altar)
	var outcome := {}
	(func() -> void: outcome["boon"] = await altar.choose()).call()
	ChoiceMenu.of(altar).close()
	assert_eq(outcome.get("boon"), &"")
	assert_false(altar.is_spent())
	assert_eq(RunState.get_boons(), [] as Array[StringName])

func test_a_boon_names_itself_and_changes_something_the_game_reads() -> void:
	var boon := _boon(&"fixture_empty", "", {}, {})
	assert_eq(boon.find_problems(ContentRegistry.active), PackedStringArray(["has no display name", "changes no stat and has no actions"]))
	boon = _boon(&"fixture_odd", "Odd", {&"fixture_no_such_stat": 2.0}, {})
	assert_eq(boon.find_problems(ContentRegistry.active), PackedStringArray(["changes stat 'fixture_no_such_stat', which no installed module or the game reads"]))
