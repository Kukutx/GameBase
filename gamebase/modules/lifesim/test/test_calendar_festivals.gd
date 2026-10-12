extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _clock_snapshot: Dictionary
var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	ContentFixture.use(self, _fixture_content())
	WorldState.clear()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	Wallet.money = 0
	Skills.reset_new_game()
	WorldClock.set_time(1, 8 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skill_snapshot)
	WorldClock.load_save_data(_clock_snapshot)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)

func test_spring_fair_claims_once_per_year_and_rewards_money_items_and_skill_xp() -> void:
	WorldClock.set_time(9, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_true(EventState.is_active(&"fixture_spring_fair"))
	assert_eq(EventState.get_year(), 1)
	assert_true(EventState.can_claim_participation(&"fixture_spring_fair"))
	assert_true(EventState.claim_participation(&"fixture_spring_fair"))
	assert_eq(Wallet.money, 150)
	assert_eq(InventoryState.get_quantity(&"fixture_seed_packet"), 5)
	assert_eq(Skills.get_xp(&"fixture_gardening"), 75)
	assert_true(EventState.has_claimed_participation(&"fixture_spring_fair"))
	assert_false(EventState.claim_participation(&"fixture_spring_fair"))
	assert_eq(Wallet.money, 150)
	assert_eq(InventoryState.get_quantity(&"fixture_seed_packet"), 5)

	WorldClock.set_time(121, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_eq(EventState.get_year(), 2)
	assert_true(EventState.is_active(&"fixture_spring_fair"))
	assert_false(EventState.has_claimed_participation(&"fixture_spring_fair"))
	assert_true(EventState.claim_participation(&"fixture_spring_fair"))
	assert_eq(Wallet.money, 300)
	assert_eq(InventoryState.get_quantity(&"fixture_seed_packet"), 10)
	assert_eq(Skills.get_xp(&"fixture_gardening"), 150)

func test_festival_claim_blocks_item_added_reentrancy() -> void:
	WorldClock.set_time(9, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_true(EventState.can_claim_participation(&"fixture_spring_fair"))
	var observed := {"entered": false, "inner_result": true}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_seed_packet" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = EventState.claim_participation(&"fixture_spring_fair")
	InventoryState.item_added.connect(listener)
	assert_true(EventState.claim_participation(&"fixture_spring_fair"))
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(EventState.has_claimed_participation(&"fixture_spring_fair"))
	assert_eq(Wallet.money, 150)
	assert_eq(InventoryState.get_quantity(&"fixture_seed_packet"), 5)
	assert_eq(Skills.get_xp(&"fixture_gardening"), 75)

func test_festival_claim_stays_bound_to_year_when_reward_signal_advances_clock() -> void:
	WorldClock.set_time(9, 10 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_eq(EventState.get_year(), 1)
	var entered := {"value": false}
	var jump_year := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_seed_packet" or bool(entered["value"]):
			return
		entered["value"] = true
		WorldClock.set_time(121, 10 * 60)
	InventoryState.item_added.connect(jump_year)
	assert_true(EventState.claim_participation(&"fixture_spring_fair"))
	if InventoryState.item_added.is_connected(jump_year):
		InventoryState.item_added.disconnect(jump_year)
	assert_true(bool(entered["value"]))
	assert_eq(EventState.get_year(), 2)
	assert_true(EventState.has_claimed_participation(&"fixture_spring_fair", 1))
	assert_false(EventState.has_claimed_participation(&"fixture_spring_fair", 2))
	assert_true(EventState.can_claim_participation(&"fixture_spring_fair"))

func test_festival_claim_state_round_trips_with_world_state() -> void:
	WorldClock.set_time(42, 12 * 60)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_true(EventState.is_active(&"fixture_summer_fair"))
	assert_true(EventState.claim_participation(&"fixture_summer_fair"))
	var snapshot := WorldState.to_save_data()
	WorldState.clear()
	assert_false(EventState.has_claimed_participation(&"fixture_summer_fair"))
	WorldState.load_save_data(snapshot)
	assert_true(EventState.has_claimed_participation(&"fixture_summer_fair"))

func test_refresh_after_loading_restores_the_active_event() -> void:
	WorldClock.set_time(9, 10 * 60)
	WorldState.load_save_data({})
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
	assert_true(EventState.is_active(&"fixture_spring_fair"))
	assert_eq(EventState.get_summary(), "Spring Fair")

# A spring fair on day 9 that rewards money, items and skill experience, and a
# summer fair on day 14 that rewards money.
func _fixture_content() -> Array:
	var seed_packet := ItemData.new()
	seed_packet.id = &"fixture_seed_packet"
	seed_packet.display_name = "Seed Packet"
	var skill := SkillData.new()
	skill.id = &"fixture_gardening"
	skill.display_name = "Gardening"
	skill.level_xp = PackedInt32Array([1000])
	var spring_fair := CalendarEventData.new()
	spring_fair.id = &"fixture_spring_fair"
	spring_fair.display_name = "Spring Fair"
	spring_fair.location_id = &"fixture_town"
	spring_fair.seasons = PackedStringArray(["Spring"])
	spring_fair.day_of_season = 9
	spring_fair.start_minute = 9 * 60
	spring_fair.end_minute = 17 * 60
	spring_fair.reward_money = 150
	spring_fair.reward_items = {"fixture_seed_packet": 5}
	spring_fair.reward_skill = skill.id
	spring_fair.reward_skill_xp = 75
	var summer_fair := CalendarEventData.new()
	summer_fair.id = &"fixture_summer_fair"
	summer_fair.display_name = "Summer Fair"
	summer_fair.location_id = &"fixture_town"
	summer_fair.seasons = PackedStringArray(["Summer"])
	summer_fair.day_of_season = 14
	summer_fair.start_minute = 9 * 60
	summer_fair.end_minute = 17 * 60
	summer_fair.reward_money = 100
	return [seed_packet, skill, spring_fair, summer_fair]
