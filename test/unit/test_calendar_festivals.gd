extends GutTest

var _clock_snapshot: Dictionary
var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()
	PlayerState.money = 0
	Skills.reset_new_game()
	WorldClock.set_time(1, 8 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skill_snapshot)
	WorldClock.load_save_data(_clock_snapshot)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)

func test_four_seasonal_festivals_are_registered_on_stable_dates() -> void:
	var expected := {
		&"spring_seed_fair": ["Spring", 9, &"starter_town"],
		&"summer_river_fair": ["Summer", 14, &"riverside_town"],
		&"fall_harbor_derby": ["Autumn", 14, &"harbor_town"],
		&"winter_lantern_night": ["Winter", 21, &"starter_town"],
	}
	assert_eq(ContentDB.get_all_calendar_events().size(), 5)
	for event_id: StringName in expected.keys():
		var event := ContentDB.get_calendar_event(event_id)
		assert_not_null(event)
		if event == null:
			continue
		var values: Array = expected[event_id]
		assert_eq(Array(event.seasons), [values[0]])
		assert_eq(event.day_of_season, values[1])
		assert_eq(event.location_id, values[2])
		assert_true(event.has_participation_reward())

func test_spring_fair_claims_once_per_year_and_rewards_money_items_and_skill_xp() -> void:
	WorldClock.set_time(9, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_true(EventState.is_active(&"spring_seed_fair"))
	assert_eq(EventState.get_year(), 1)
	assert_true(EventState.can_claim_participation(&"spring_seed_fair"))
	assert_true(EventState.claim_participation(&"spring_seed_fair"))
	assert_eq(PlayerState.money, 150)
	assert_eq(InventoryState.get_quantity(&"carrot_seeds"), 5)
	assert_eq(Skills.get_xp(SkillManager.FARMING), 75)
	assert_true(EventState.has_claimed_participation(&"spring_seed_fair"))
	assert_false(EventState.claim_participation(&"spring_seed_fair"))
	assert_eq(PlayerState.money, 150)
	assert_eq(InventoryState.get_quantity(&"carrot_seeds"), 5)

	WorldClock.set_time(121, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_eq(EventState.get_year(), 2)
	assert_true(EventState.is_active(&"spring_seed_fair"))
	assert_false(EventState.has_claimed_participation(&"spring_seed_fair"))
	assert_true(EventState.claim_participation(&"spring_seed_fair"))
	assert_eq(PlayerState.money, 300)
	assert_eq(InventoryState.get_quantity(&"carrot_seeds"), 10)
	assert_eq(Skills.get_xp(SkillManager.FARMING), 150)

func test_festival_claim_blocks_item_added_reentrancy() -> void:
	WorldClock.set_time(9, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_true(EventState.can_claim_participation(&"spring_seed_fair"))
	var observed := {"entered": false, "inner_result": true}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"carrot_seeds" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = EventState.claim_participation(&"spring_seed_fair")
	InventoryState.item_added.connect(listener)
	assert_true(EventState.claim_participation(&"spring_seed_fair"))
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(EventState.has_claimed_participation(&"spring_seed_fair"))
	assert_eq(PlayerState.money, 150)
	assert_eq(InventoryState.get_quantity(&"carrot_seeds"), 5)
	assert_eq(Skills.get_xp(SkillManager.FARMING), 75)

func test_festival_claim_stays_bound_to_year_when_reward_signal_advances_clock() -> void:
	WorldClock.set_time(9, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_eq(EventState.get_year(), 1)
	var entered := {"value": false}
	var jump_year := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"carrot_seeds" or bool(entered["value"]):
			return
		entered["value"] = true
		WorldClock.set_time(121, 10 * 60)
	InventoryState.item_added.connect(jump_year)
	assert_true(EventState.claim_participation(&"spring_seed_fair"))
	if InventoryState.item_added.is_connected(jump_year):
		InventoryState.item_added.disconnect(jump_year)
	assert_true(bool(entered["value"]))
	assert_eq(EventState.get_year(), 2)
	assert_true(EventState.has_claimed_participation(&"spring_seed_fair", 1))
	assert_false(EventState.has_claimed_participation(&"spring_seed_fair", 2))
	assert_true(EventState.can_claim_participation(&"spring_seed_fair"))

func test_festival_claim_state_round_trips_with_world_state() -> void:
	WorldClock.set_time(42, 12 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_true(EventState.is_active(&"summer_river_fair"))
	assert_true(EventState.claim_participation(&"summer_river_fair"))
	var snapshot := WorldState.to_save_data()
	WorldState.clear()
	assert_false(EventState.has_claimed_participation(&"summer_river_fair"))
	WorldState.load_save_data(snapshot)
	assert_true(EventState.has_claimed_participation(&"summer_river_fair"))

func test_loading_old_festival_time_rebuilds_missing_active_event_world_flag() -> void:
	var snapshot := {
		"weather": WeatherState.to_save_data(),
		"shipping": ShippingState.to_save_data(),
		"clock": {"day": 9, "minute_of_day": 10 * 60},
		"buffs": BuffState.to_save_data(),
		"inventory": InventoryState.to_save_data(),
		"player_state": PlayerState.to_save_data(),
		"world": {},
		"relationships": RelationshipState.to_save_data(),
		"npc_memory": NpcMemory.to_save_data(),
		"quests": QuestState.to_save_data(),
		"skills": Skills.to_save_data(),
		"fishing": FishingState.to_save_data(),
		"scene": "",
	}
	assert_true(await SaveManager.apply_snapshot(snapshot))
	assert_true(EventState.is_active(&"spring_seed_fair"))
	assert_true(WorldState.get_bool(&"event:spring_seed_fair:active"))

func test_event_refresh_clears_orphan_active_flags_without_deleting_history() -> void:
	WorldState.set_value(&"event:retired_festival:active", true)
	WorldState.set_value(&"event:retired_festival:year:1:participated", true)
	EventState.refresh(1, 8 * 60, true)
	assert_false(WorldState.get_bool(&"event:retired_festival:active"))
	assert_false(WorldState.to_save_data().has("event:retired_festival:active"))
	assert_true(WorldState.get_bool(&"event:retired_festival:year:1:participated"))

func test_all_festival_booths_are_exposed_in_playable_town_scenes() -> void:
	var starter := (load("res://game/world/dev_world.tscn") as PackedScene).instantiate()
	var riverside := (load("res://game/world/riverside_town.tscn") as PackedScene).instantiate()
	var harbor := (load("res://game/world/harbor_town.tscn") as PackedScene).instantiate()
	autofree(starter)
	autofree(riverside)
	autofree(harbor)
	assert_not_null(starter.get_node_or_null("SpringSeedFairBooth"))
	assert_not_null(starter.get_node_or_null("WinterLanternBooth"))
	assert_not_null(riverside.get_node_or_null("SummerRiverFairBooth"))
	assert_not_null(harbor.get_node_or_null("FallHarborDerbyBooth"))
	assert_true(ResourceLoader.exists("res://gamebase/modules/lifesim/calendar/calendar_event_booth.tscn"))
