extends GutTest

## The daily contracts Farm1's content offers: which ores at each mine depth,
## which crops, forage and fish late in a season. The contracts themselves are
## tested with the progression module.

var _world_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _random_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	_random_snapshot = GameRandom.to_save_data()
	WorldState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	GameRandom.load_save_data(_random_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_mining_nodes_unlock_at_the_mine_depth_of_their_tier() -> void:
	var expected_floors := {
		&"stone_rock": 1,
		&"copper_rock": 1,
		&"iron_rock": 6,
		&"gold_rock": 20,
		&"iridium_rock": 60,
	}
	for raw_id: Variant in expected_floors.keys():
		var node := MiningNodeData.find(StringName(String(raw_id)))
		assert_not_null(node)
		if node != null:
			assert_eq(node.minimum_mine_floor, int(expected_floors[raw_id]))

func test_farm1_offers_every_kind_of_daily_contract_over_a_year() -> void:
	var seen: Dictionary = {}
	for day in range(1, 121):
		seen[String(DailyContractState.generate_contract_for_day(day).get("objective_type", ""))] = true
	for required_type: StringName in [DailyContractService.FORAGE, DailyContractService.FISH, DailyContractService.MINE, DailyContractService.SHIP, DailyContractService.HARVEST]:
		assert_true(seen.has(String(required_type)), "Daily contracts never generated objective type %s" % required_type)

func test_mining_contracts_offer_the_ores_of_the_deepest_floor_reached() -> void:
	var cases := [
		{"floor": 1, "allowed": [&"stone", &"copper_ore"]},
		{"floor": 6, "allowed": [&"stone", &"copper_ore", &"iron_ore"]},
		{"floor": 20, "allowed": [&"stone", &"copper_ore", &"iron_ore", &"gold_ore"]},
		{"floor": 60, "allowed": [&"stone", &"copper_ore", &"iron_ore", &"gold_ore", &"iridium_ore"]},
	]
	for case: Dictionary in cases:
		WorldState.clear()
		MineState.set_floor(int(case["floor"]))
		var mine_targets: Array[StringName] = []
		for target: String in _targets_of(DailyContractService.MINE, 1):
			mine_targets.append(StringName(target))
		mine_targets.sort()
		var allowed: Array = case["allowed"]
		allowed.sort()
		assert_eq(mine_targets, allowed, "Wrong mining contract pool at Floor %d" % int(case["floor"]))

func test_autumn_harvest_contracts_follow_pumpkin_and_carrot_growth_times() -> void:
	# Autumn 21 leaves eight growth days, enough for a Pumpkin; Autumn 22 does not.
	assert_true(_targets_of(DailyContractService.HARVEST, 77).has("pumpkin"))
	var day_22_targets := _targets_of(DailyContractService.HARVEST, 78)
	assert_false(day_22_targets.has("pumpkin"))
	assert_true(day_22_targets.has("carrot"))
	# On the last day of Autumn no fresh crop can mature.
	assert_eq(_targets_of(DailyContractService.HARVEST, 84), [] as Array[String])

func test_berry_contracts_stop_before_winter_while_wood_contracts_continue() -> void:
	# Autumn 26 plus two contract days ends on Autumn 28; Autumn 27 crosses into Winter.
	assert_true(_types_targeting(82, "berry").has(String(DailyContractService.FORAGE)))
	assert_true(_types_targeting(82, "berry").has(String(DailyContractService.SHIP)))
	assert_false(_types_targeting(83, "berry").has(String(DailyContractService.FORAGE)))
	assert_false(_types_targeting(83, "berry").has(String(DailyContractService.SHIP)))
	assert_true(_types_targeting(83, "wood").has(String(DailyContractService.FORAGE)))
	assert_true(_types_targeting(83, "wood").has(String(DailyContractService.SHIP)))

func test_storm_eel_contracts_are_offered_only_while_a_storm_window_remains() -> void:
	var storm_day := 0
	for seed in range(1, 500):
		GameRandom.set_seed(seed)
		for day in range(1, 83):
			if GameCalendar.current().get_season_name(day) == "Winter":
				continue
			if WeatherState.get_weather_id(day) != &"storm":
				continue
			if WeatherState.get_weather_id(day + 1) == &"storm":
				continue
			if WeatherState.get_weather_id(day + 2) == &"storm":
				continue
			storm_day = day
			break
		if storm_day > 0:
			break
	assert_gt(storm_day, 0)
	if storm_day <= 0:
		return
	WorldClock.set_time(storm_day, 10 * 60)
	assert_true(_targets_of(DailyContractService.FISH, storm_day).has("storm_eel"))
	WorldClock.set_time(storm_day, 23 * 60 + 30)
	assert_false(_targets_of(DailyContractService.FISH, storm_day).has("storm_eel"))

func _targets_of(objective_type: StringName, day: int) -> Array[String]:
	var targets: Array[String] = []
	for candidate: Dictionary in DailyContractState.call("_build_candidates", day):
		if StringName(String(candidate.get("objective_type", ""))) == objective_type:
			targets.append(String(candidate.get("target_item_id", "")))
	return targets

func _types_targeting(day: int, item_id: String) -> Array[String]:
	var types: Array[String] = []
	for candidate: Dictionary in DailyContractState.call("_build_candidates", day):
		if String(candidate.get("target_item_id", "")) == item_id:
			types.append(String(candidate.get("objective_type", "")))
	return types
