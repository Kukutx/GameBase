extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _inventory_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _profile: NpcProfileData

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	InventoryState.clear()
	_profile = NpcProfileData.new()
	_profile.id = &"fixture_npc"
	_profile.display_name = "Fixture"
	_profile.birthday_season = "Spring"
	_profile.birthday_day = 14
	_profile.loved_items = [&"fixture_berry"]
	_profile.liked_items = [&"fixture_radish"]
	_profile.disliked_items = [&"fixture_twig"]
	ContentFixture.use(self, [_profile, _item(&"fixture_berry"), _item(&"fixture_radish"), _item(&"fixture_twig")])

func after_each() -> void:
	# The game's content is active again before the inventory loads its items.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)

func test_profile_scores_loved_liked_and_disliked_gifts() -> void:
	assert_eq(_profile.friendship_for_gift(ItemData.find(&"fixture_berry")), 80)
	assert_eq(_profile.friendship_for_gift(ItemData.find(&"fixture_radish")), 45)
	assert_eq(_profile.friendship_for_gift(ItemData.find(&"fixture_twig")), -20)

func test_birthdays_are_calendar_based_and_double_gift_friendship() -> void:
	assert_true(_profile.is_birthday(14))
	assert_false(_profile.is_birthday(13))
	WorldClock.set_time(14, 10 * 60)
	InventoryState.add_item_by_id(&"fixture_berry", 1)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	assert_eq(state.give_gift(_profile, &"fixture_berry"), 160)
	assert_eq(state.get_points(&"fixture_npc"), 160)

func test_gift_daily_limit_blocks_item_removed_reentrancy() -> void:
	WorldClock.set_time(1, 10 * 60)
	InventoryState.add_item_by_id(&"fixture_berry", 2)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	var observed := {"entered": false, "inner_delta": -999}
	var reenter := func(_item_id: StringName, _quantity: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_delta"] = state.give_gift(_profile, &"fixture_berry")
	InventoryState.item_removed.connect(reenter)
	var outer_delta := state.give_gift(_profile, &"fixture_berry")
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_eq(outer_delta, _profile.friendship_for_gift(ItemData.find(&"fixture_berry")))
	assert_eq(int(observed["inner_delta"]), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), 1)
	assert_eq(state.get_points(&"fixture_npc"), outer_delta)

func test_relationship_load_sanitizes_points_and_future_daily_markers() -> void:
	WorldClock.set_time(12, 10 * 60)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	state.load_save_data({
		"points": {"fixture_npc": 999999, "fixture_other_npc": -300},
		"last_talk_day": {"fixture_npc": 9999, "fixture_other_npc": -2},
		"last_gift_day": {"fixture_npc": 7777, "fixture_other_npc": -4},
	})
	assert_eq(state.get_points(&"fixture_npc"), RelationshipManager.POINTS_PER_HEART * RelationshipManager.MAX_HEARTS)
	assert_eq(state.get_points(&"fixture_other_npc"), 0)
	var saved := state.to_save_data()
	assert_eq(int((saved["last_talk_day"] as Dictionary).get("fixture_npc", -1)), 12)
	assert_eq(int((saved["last_talk_day"] as Dictionary).get("fixture_other_npc", -1)), 0)
	assert_eq(int((saved["last_gift_day"] as Dictionary).get("fixture_npc", -1)), 12)
	assert_eq(int((saved["last_gift_day"] as Dictionary).get("fixture_other_npc", -1)), 0)

func test_relationship_points_are_bounded_and_persist() -> void:
	var state := RelationshipManager.new()
	add_child_autofree(state)
	state.add_friendship(&"fixture_npc", 600)
	assert_eq(state.get_points(&"fixture_npc"), 600)
	assert_eq(state.get_hearts(&"fixture_npc"), 2)

	var restored := RelationshipManager.new()
	add_child_autofree(restored)
	restored.load_save_data(state.to_save_data())
	assert_eq(restored.get_points(&"fixture_npc"), 600)

## A giftable item (a gift is no tool or seed).
func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = ItemData.Kind.GIFT
	return item
