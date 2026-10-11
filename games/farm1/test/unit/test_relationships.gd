extends GutTest

func test_profile_scores_loved_liked_and_disliked_gifts() -> void:
	var profile := NpcProfileData.new()
	profile.loved_items = [&"berry"]
	profile.liked_items = [&"turnip"]
	profile.disliked_items = [&"wood"]

	assert_eq(profile.friendship_for_gift(ItemData.find(&"berry")), 80)
	assert_eq(profile.friendship_for_gift(ItemData.find(&"turnip")), 45)
	assert_eq(profile.friendship_for_gift(ItemData.find(&"wood")), -20)

func test_birthdays_are_calendar_based_and_double_gift_friendship() -> void:
	var inventory_snapshot := InventoryState.to_save_data()
	var clock_snapshot := WorldClock.to_save_data()
	InventoryState.clear()
	var profile := NpcProfileData.find(&"mira")
	assert_not_null(profile)
	assert_true(profile.is_birthday(14))
	assert_false(profile.is_birthday(13))
	WorldClock.set_time(14, 10 * 60)
	InventoryState.add_item_by_id(&"berry", 1)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	assert_eq(state.give_gift(profile, &"berry"), 160)
	assert_eq(state.get_points(&"mira"), 160)
	WorldClock.load_save_data(clock_snapshot)
	InventoryState.load_save_data(inventory_snapshot)

func test_gift_daily_limit_blocks_item_removed_reentrancy() -> void:
	var inventory_snapshot := InventoryState.to_save_data()
	var clock_snapshot := WorldClock.to_save_data()
	InventoryState.clear()
	WorldClock.set_time(1, 10 * 60)
	InventoryState.add_item_by_id(&"berry", 2)
	var profile := NpcProfileData.find(&"mira")
	assert_not_null(profile)
	if profile == null:
		WorldClock.load_save_data(clock_snapshot)
		InventoryState.load_save_data(inventory_snapshot)
		return
	var state := RelationshipManager.new()
	add_child_autofree(state)
	var observed := {"entered": false, "inner_delta": -999}
	var reenter := func(_item_id: StringName, _quantity: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_delta"] = state.give_gift(profile, &"berry")
	InventoryState.item_removed.connect(reenter)
	var outer_delta := state.give_gift(profile, &"berry")
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_eq(outer_delta, profile.friendship_for_gift(ItemData.find(&"berry")))
	assert_eq(int(observed["inner_delta"]), 0)
	assert_eq(InventoryState.get_quantity(&"berry"), 1)
	assert_eq(state.get_points(&"mira"), outer_delta)
	WorldClock.load_save_data(clock_snapshot)
	InventoryState.load_save_data(inventory_snapshot)

func test_relationship_load_sanitizes_points_and_future_daily_markers() -> void:
	var clock_snapshot := WorldClock.to_save_data()
	WorldClock.set_time(12, 10 * 60)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	state.load_save_data({
		"points": {"mira": 999999, "rowan": -300},
		"last_talk_day": {"mira": 9999, "rowan": -2},
		"last_gift_day": {"mira": 7777, "rowan": -4},
	})
	assert_eq(state.get_points(&"mira"), RelationshipManager.POINTS_PER_HEART * RelationshipManager.MAX_HEARTS)
	assert_eq(state.get_points(&"rowan"), 0)
	var saved := state.to_save_data()
	assert_eq(int((saved["last_talk_day"] as Dictionary).get("mira", -1)), 12)
	assert_eq(int((saved["last_talk_day"] as Dictionary).get("rowan", -1)), 0)
	assert_eq(int((saved["last_gift_day"] as Dictionary).get("mira", -1)), 12)
	assert_eq(int((saved["last_gift_day"] as Dictionary).get("rowan", -1)), 0)
	WorldClock.load_save_data(clock_snapshot)

func test_relationship_points_are_bounded_and_persist() -> void:
	var state := RelationshipManager.new()
	add_child_autofree(state)
	state.add_friendship(&"mira", 600)
	assert_eq(state.get_points(&"mira"), 600)
	assert_eq(state.get_hearts(&"mira"), 2)

	var restored := RelationshipManager.new()
	add_child_autofree(restored)
	restored.load_save_data(state.to_save_data())
	assert_eq(restored.get_points(&"mira"), 600)
