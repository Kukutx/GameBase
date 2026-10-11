extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _world_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _random_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	_random_snapshot = GameRandom.to_save_data()
	ContentFixture.use(self, _content())
	WorldState.clear()
	PlayerState.reset_new_game()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# The game's content is active again before the stores load their state.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	GameRandom.load_save_data(_random_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_contract_generation_is_deterministic_and_covers_all_objective_types() -> void:
	GameRandom.set_seed(4242)
	var first := DailyContractState.generate_contract_for_day(12)
	var second := DailyContractState.generate_contract_for_day(12)
	assert_eq(first, second)
	var seen: Dictionary = {}
	for day in range(1, 121):
		var contract := DailyContractState.generate_contract_for_day(day)
		assert_false(contract.is_empty())
		seen[String(contract.get("objective_type", ""))] = true
	for required_type: StringName in [DailyContractService.FORAGE, DailyContractService.FISH, DailyContractService.MINE, DailyContractService.SHIP, DailyContractService.HARVEST]:
		assert_true(seen.has(String(required_type)), "Daily contracts never generated objective type %s" % required_type)

func test_mining_contract_targets_follow_the_deepest_mine_floor() -> void:
	var cases := [
		{"floor": 1, "allowed": [&"fixture_pebble"]},
		{"floor": 5, "allowed": [&"fixture_pebble"]},
		{"floor": 6, "allowed": [&"fixture_ore", &"fixture_pebble"]},
	]
	for case: Dictionary in cases:
		WorldState.clear()
		MineState.set_floor(int(case["floor"]))
		var mine_targets: Array[StringName] = []
		for candidate: Dictionary in DailyContractState.call("_build_candidates", 1):
			if StringName(String(candidate.get("objective_type", ""))) == DailyContractService.MINE:
				mine_targets.append(StringName(String(candidate.get("target_item_id", ""))))
		mine_targets.sort()
		var allowed: Array = case["allowed"]
		allowed.sort()
		assert_eq(mine_targets, allowed, "Wrong mining contract pool at Floor %d" % int(case["floor"]))

func test_harvest_contracts_respect_crop_growth_time_and_season_end() -> void:
	# Autumn Day 21 has eight growth days left, so the gourd (8 days) is still valid.
	var day_21_targets: Dictionary = {}
	for candidate: Dictionary in DailyContractState.call("_build_candidates", 77):
		if StringName(String(candidate.get("objective_type", ""))) != DailyContractService.HARVEST:
			continue
		day_21_targets[String(candidate.get("target_item_id", ""))] = int(candidate.get("duration_days", 0))
	assert_true(day_21_targets.has("fixture_gourd"))
	assert_gte(int(day_21_targets.get("fixture_gourd", 0)), 8)

	# Autumn Day 22 has only seven growth days left; a fresh gourd cannot mature.
	var day_22_targets: Array[String] = []
	for candidate: Dictionary in DailyContractState.call("_build_candidates", 78):
		if StringName(String(candidate.get("objective_type", ""))) == DailyContractService.HARVEST:
			day_22_targets.append(String(candidate.get("target_item_id", "")))
	assert_false(day_22_targets.has("fixture_gourd"))
	assert_true(day_22_targets.has("fixture_radish"))

	# On the final day of Autumn no fresh seasonal crop can mature from scratch.
	var final_day_harvests := 0
	for candidate: Dictionary in DailyContractState.call("_build_candidates", 84):
		if StringName(String(candidate.get("objective_type", ""))) == DailyContractService.HARVEST:
			final_day_harvests += 1
	assert_eq(final_day_harvests, 0)

func test_seasonal_forage_contracts_do_not_cross_into_an_unavailable_season() -> void:
	# Autumn 26 + two contract days ends on Autumn 28, so the berry is still safe.
	var safe_types := _types_targeting(82, "fixture_berry")
	assert_true(safe_types.has(String(DailyContractService.FORAGE)))
	assert_true(safe_types.has(String(DailyContractService.SHIP)))

	# Autumn 27 + two contract days crosses into Winter 1. The berry no longer has
	# a source for the full deadline window and must be removed from both pools.
	var crossing_types := _types_targeting(83, "fixture_berry")
	assert_false(crossing_types.has(String(DailyContractService.FORAGE)))
	assert_false(crossing_types.has(String(DailyContractService.SHIP)))

	# All-season forage remains eligible across the same boundary.
	var twig_types := _types_targeting(83, "fixture_twig")
	assert_true(twig_types.has(String(DailyContractService.FORAGE)))
	assert_true(twig_types.has(String(DailyContractService.SHIP)))

func test_weather_locked_fish_contracts_require_a_remaining_window_inside_deadline() -> void:
	var storm_day := 0
	for seed in range(1, 500):
		GameRandom.set_seed(seed)
		for day in range(1, 83):
			if GameClock.get_season_name_for_day(day) == "Winter":
				continue
			if WeatherState.get_weather_name(WeatherState.get_weather_for_day(day)) != "Storm":
				continue
			if WeatherState.get_weather_name(WeatherState.get_weather_for_day(day + 1)) == "Storm":
				continue
			if WeatherState.get_weather_name(WeatherState.get_weather_for_day(day + 2)) == "Storm":
				continue
			storm_day = day
			break
		if storm_day > 0:
			break
	assert_gt(storm_day, 0)
	if storm_day <= 0:
		return

	WorldClock.set_time(storm_day, 10 * 60)
	var daytime_targets := _targets_of(DailyContractService.FISH, storm_day)
	assert_true(daytime_targets.has("fixture_eel"))

	WorldClock.set_time(storm_day, 23 * 60 + 30)
	var late_targets := _targets_of(DailyContractService.FISH, storm_day)
	assert_false(late_targets.has("fixture_eel"))

func test_removed_contract_target_is_withdrawn_but_completed_reward_is_preserved() -> void:
	var invalid := {
		"objective_type": String(DailyContractService.FISH),
		"target_item_id": "removed_contract_item",
		"required": 1,
		"reward_money": 222,
		"generated_day": WorldClock.day,
		"expires_day": WorldClock.day + 2,
		"accepted": true,
		"progress": 0,
		"completed": false,
		"claimed": false,
	}
	WorldState.set_value(DailyContractService.STATE_KEY, invalid)
	var replacement := DailyContractState.get_contract()
	assert_ne(String(replacement.get("target_item_id", "")), "removed_contract_item")
	assert_false(bool(replacement.get("accepted", true)))
	assert_eq(int(replacement.get("generated_day", 0)), WorldClock.day)

	invalid["completed"] = true
	invalid["progress"] = 1
	WorldState.set_value(DailyContractService.STATE_KEY, invalid)
	var completed := DailyContractState.get_contract()
	assert_eq(String(completed.get("target_item_id", "")), "removed_contract_item")
	var money_before := PlayerState.money
	assert_eq(DailyContractState.claim(), 222)
	assert_eq(PlayerState.money, money_before + 222)

func test_contract_state_sanitizes_malformed_nested_values_without_crashing() -> void:
	WorldState.set_value(DailyContractService.STATE_KEY, {
		"objective_type": String(DailyContractService.FORAGE),
		"target_item_id": "fixture_berry",
		"required": {"bad": true},
		"reward_money": [999],
		"generated_day": {"bad": true},
		"expires_day": [999],
		"accepted": {"truthy": true},
		"progress": {"bad": true},
		"completed": false,
		"claimed": false,
	})
	var normalized := DailyContractState.call("_get_state") as Dictionary
	assert_eq(int(normalized.get("required", 0)), 1)
	assert_eq(int(normalized.get("progress", -1)), 0)
	assert_eq(int(normalized.get("reward_money", -1)), 0)
	assert_eq(int(normalized.get("generated_day", -1)), 0)
	assert_false(bool(normalized.get("accepted", true)))
	assert_eq(DailyContractState.get_display_title(normalized), "Forage 1 Wild Berry")
	assert_eq(DailyContractState.get_display_description(normalized), "Forage 1 Wild Berry for the town request.")
	assert_eq(DailyContractState.get_display_title({"objective_type": String(DailyContractService.FISH), "target_item_id": "removed_contract_item"}), "Daily contract")

	# Claimed is a durable fact: if it is genuinely boolean true, completion and
	# acceptance are inferred even when older/malformed saves omit those booleans.
	WorldState.set_value(DailyContractService.STATE_KEY, {
		"objective_type": String(DailyContractService.FORAGE),
		"target_item_id": "fixture_berry",
		"required": 3,
		"reward_money": 100,
		"generated_day": WorldClock.day,
		"expires_day": WorldClock.day + 2,
		"accepted": false,
		"completed": false,
		"claimed": true,
	})
	normalized = DailyContractState.call("_get_state") as Dictionary
	assert_true(bool(normalized.get("accepted", false)))
	assert_true(bool(normalized.get("completed", false)))
	assert_true(bool(normalized.get("claimed", false)))

func test_accepted_contract_progresses_from_matching_game_event_and_claims_once() -> void:
	var contract := DailyContractState.get_contract()
	assert_false(contract.is_empty())
	assert_true(DailyContractState.accept())
	contract = DailyContractState.get_contract()
	var objective := StringName(String(contract["objective_type"]))
	var target := StringName(String(contract["target_item_id"]))
	var required := int(contract["required"])
	match objective:
		DailyContractService.FORAGE:
			ItemsEvents.item_foraged.emit(target, required)
		DailyContractService.FISH:
			LifesimEvents.fish_caught.emit(&"contract_fish", target)
			for _index in range(required - 1):
				LifesimEvents.fish_caught.emit(&"contract_fish", target)
		DailyContractService.MINE:
			LifesimEvents.resource_mined.emit(&"contract_node", target, required)
		DailyContractService.SHIP:
			ShippingState.item_shipped.emit(target, required, 0)
		DailyContractService.HARVEST:
			LifesimEvents.crop_harvested.emit(&"contract_crop", target, required)
	contract = DailyContractState.get_contract()
	assert_true(bool(contract["completed"]))
	assert_eq(int(contract["progress"]), required)
	var money_before := PlayerState.money
	var reward := DailyContractState.claim()
	assert_eq(reward, int(contract["reward_money"]))
	assert_eq(PlayerState.money, money_before + reward)
	assert_eq(DailyContractState.claim(), 0)

func test_contract_claim_commits_before_money_changed_reentrancy() -> void:
	var state := DailyContractState.get_contract()
	state["accepted"] = true
	state["completed"] = true
	state["claimed"] = false
	state["reward_money"] = 333
	WorldState.set_value(DailyContractService.STATE_KEY, state)
	var money_before := PlayerState.money
	var observed := {"entered": false, "inner_reward": -1}
	var reenter := func(_money: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_reward"] = DailyContractState.claim()
	PlayerState.money_changed.connect(reenter)
	assert_eq(DailyContractState.claim(), 333)
	if PlayerState.money_changed.is_connected(reenter):
		PlayerState.money_changed.disconnect(reenter)
	assert_eq(int(observed["inner_reward"]), 0)
	assert_eq(PlayerState.money, money_before + 333)
	assert_true(bool(DailyContractState.get_contract().get("claimed", false)))

func test_unaccepted_offer_refreshes_next_day() -> void:
	var day_one := DailyContractState.get_contract()
	assert_eq(int(day_one["generated_day"]), 1)
	WorldClock.set_time(2, 8 * 60)
	var day_two := DailyContractState.get_contract()
	assert_eq(int(day_two["generated_day"]), 2)

func test_incomplete_accepted_contract_expires_and_refreshes_after_deadline() -> void:
	var contract := DailyContractState.get_contract()
	assert_true(DailyContractState.accept())
	var expires := int(contract["expires_day"])
	WorldClock.set_time(expires + 1, 8 * 60)
	var refreshed := DailyContractState.get_contract()
	assert_eq(int(refreshed["generated_day"]), expires + 1)
	assert_false(bool(refreshed["accepted"]))

func test_notice_board_and_menu_scenes_are_available() -> void:
	assert_true(ResourceLoader.exists("res://gamebase/modules/progression/contracts/notice_board.tscn"))
	assert_true(ResourceLoader.exists("res://gamebase/modules/progression/contracts/daily_contract_menu.tscn"))

## The target items of the `objective_type` candidates on `day`.
func _targets_of(objective_type: StringName, day: int) -> Array[String]:
	var targets: Array[String] = []
	for candidate: Dictionary in DailyContractState.call("_build_candidates", day):
		if StringName(String(candidate.get("objective_type", ""))) == objective_type:
			targets.append(String(candidate.get("target_item_id", "")))
	return targets

## The objective types of the candidates on `day` that target `item_id`.
func _types_targeting(day: int, item_id: String) -> Array[String]:
	var types: Array[String] = []
	for candidate: Dictionary in DailyContractState.call("_build_candidates", day):
		if String(candidate.get("target_item_id", "")) == item_id:
			types.append(String(candidate.get("objective_type", "")))
	return types

## A source for every kind of contract: a berry foraged until autumn ends and a
## twig foraged all year, a trout caught any day and an eel only in a storm,
## a pebble from the first mine floor and an ore from the sixth, a radish
## (three days) and an autumn gourd (eight days).
func _content() -> Array:
	var berry_patch := ForageEntryData.new()
	berry_patch.id = &"fixture_berry_patch"
	berry_patch.item_id = &"fixture_berry"
	berry_patch.seasons = PackedStringArray(["Spring", "Summer", "Autumn"])
	var twig_pile := ForageEntryData.new()
	twig_pile.id = &"fixture_twig_pile"
	twig_pile.item_id = &"fixture_twig"
	var trout := FishData.new()
	trout.id = &"fixture_trout_fish"
	trout.item_id = &"fixture_trout"
	var eel := FishData.new()
	eel.id = &"fixture_eel_fish"
	eel.item_id = &"fixture_eel"
	eel.seasons = PackedStringArray(["Spring", "Summer", "Autumn"])
	eel.start_minute = 8 * 60
	eel.end_minute = 23 * 60
	eel.allowed_weather = PackedStringArray(["Storm"])
	eel.difficulty = 7
	var pebble_rock := MiningNodeData.new()
	pebble_rock.id = &"fixture_pebble_rock"
	pebble_rock.drop_item_id = &"fixture_pebble"
	pebble_rock.minimum_mine_floor = 1
	var ore_rock := MiningNodeData.new()
	ore_rock.id = &"fixture_ore_rock"
	ore_rock.drop_item_id = &"fixture_ore"
	ore_rock.minimum_mine_floor = 6
	var radish := CropData.new()
	radish.id = &"fixture_radish_crop"
	radish.harvest_item_id = &"fixture_radish"
	radish.days_to_mature = 3
	radish.allowed_seasons = PackedStringArray(["Spring", "Autumn"])
	var gourd := CropData.new()
	gourd.id = &"fixture_gourd_crop"
	gourd.harvest_item_id = &"fixture_gourd"
	gourd.days_to_mature = 8
	gourd.allowed_seasons = PackedStringArray(["Autumn"])
	var berry := _item(&"fixture_berry", 10)
	berry.display_name = "Wild Berry"
	return [
		berry_patch, twig_pile, trout, eel, pebble_rock, ore_rock, radish, gourd,
		berry,
		_item(&"fixture_twig", 2),
		_item(&"fixture_trout", 20),
		_item(&"fixture_eel", 40),
		_item(&"fixture_pebble", 2),
		_item(&"fixture_ore", 15),
		_item(&"fixture_radish", 30),
		_item(&"fixture_gourd", 80),
	]

func _item(id: StringName, sell_price: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.sell_price = sell_price
	return item
