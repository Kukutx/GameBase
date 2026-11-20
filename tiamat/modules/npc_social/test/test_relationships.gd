extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

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
	ContentFixture.use(self, [_profile, _item(&"fixture_berry"), _item(&"fixture_radish"), _item(&"fixture_twig"),
		_location(&"fixture_square", "Fixture Square"), _location(&"fixture_home", "Fixture Home")])

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

func test_only_the_first_talk_of_a_day_counts() -> void:
	WorldClock.set_time(3, 10 * 60)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	assert_true(state.record_talk(&"fixture_npc"), "the first talk today")
	assert_false(state.record_talk(&"fixture_npc"), "a second talk the same day")
	assert_eq(state.get_points(&"fixture_npc"), 10, "only the first adds friendship")
	WorldClock.set_time(4, 10 * 60)
	assert_true(state.record_talk(&"fixture_npc"), "the next day's first talk")

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

func test_profile_tells_how_it_takes_a_gift() -> void:
	assert_eq(_profile.taste_of(ItemData.find(&"fixture_berry")), NpcProfileData.Taste.LOVED)
	assert_eq(_profile.taste_of(ItemData.find(&"fixture_radish")), NpcProfileData.Taste.LIKED)
	assert_eq(_profile.taste_of(ItemData.find(&"fixture_twig")), NpcProfileData.Taste.DISLIKED)
	assert_eq(_profile.taste_of(_item(&"fixture_pebble")), NpcProfileData.Taste.NEUTRAL)

func test_a_gift_tells_how_the_npc_takes_it_and_the_save_keeps_it() -> void:
	WorldClock.set_time(3, 10 * 60)
	for item_id: StringName in [&"fixture_berry", &"fixture_radish", &"fixture_twig"]:
		InventoryState.add_item_by_id(item_id, 1)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	assert_eq(state.get_known_taste(&"fixture_npc", &"fixture_berry"), -1, "nothing is known before a gift")
	assert_eq(state.describe_known_tastes(&"fixture_npc"), PackedStringArray())
	assert_false(state.has_given_gift_today(&"fixture_npc"))
	state.give_gift(_profile, &"fixture_twig")
	assert_true(state.has_given_gift_today(&"fixture_npc"))
	WorldClock.set_time(4, 10 * 60)
	assert_false(state.has_given_gift_today(&"fixture_npc"), "a new day takes another gift")
	state.give_gift(_profile, &"fixture_berry")
	WorldClock.set_time(5, 10 * 60)
	state.give_gift(_profile, &"fixture_radish")
	assert_eq(state.get_known_taste(&"fixture_npc", &"fixture_berry"), NpcProfileData.Taste.LOVED)
	var told := PackedStringArray([tr("Loves: %s") % "Fixture Berry", tr("Likes: %s") % "Fixture Radish", tr("Dislikes: %s") % "Fixture Twig"])
	assert_eq(state.describe_known_tastes(&"fixture_npc"), told, "the best first")
	assert_eq(state.describe_known_takers(&"fixture_twig"), PackedStringArray([tr("%s dislikes it") % "Fixture"]))
	assert_eq(state.describe_known_takers(&"fixture_pebble"), PackedStringArray(), "an item never given")
	var saved := state.to_save_data()
	(saved["known_tastes"] as Dictionary)["fixture_npc"]["fixture_pebble"] = 9
	(saved["known_tastes"] as Dictionary)["fixture_other_npc"] = "not tastes"
	var restored := RelationshipManager.new()
	add_child_autofree(restored)
	restored.load_save_data(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(restored.describe_known_tastes(&"fixture_npc"), told, "a save keeps what the gifts told")
	assert_eq(restored.get_known_taste(&"fixture_npc", &"fixture_pebble"), -1, "a taste out of range is dropped")
	restored.load_save_data({"points": {}})
	assert_eq(restored.describe_known_tastes(&"fixture_npc"), PackedStringArray(), "a save from before tastes were kept")

func test_the_townsfolk_page_tells_where_each_npc_is_now() -> void:
	_profile.default_location_id = &"fixture_home"
	_profile.schedule_entries = [_entry(8 * 60, &"fixture_square", "Morning walk"), _entry(18 * 60, &"", "Supper")]
	WorldClock.set_time(3, 9 * 60)
	assert_eq(_profile.describe_whereabouts(), "Fixture Square · Morning walk")
	WorldClock.set_time(3, 19 * 60)
	assert_eq(_profile.describe_whereabouts(), "Fixture Home · Supper", "an entry without a location is at the default one")
	WorldClock.set_time(4, 6 * 60)
	assert_eq(_profile.describe_whereabouts(), "Fixture Home · Supper", "before the day's first entry, where the day before left them")
	var state := RelationshipManager.new()
	add_child_autofree(state)
	assert_eq(state.describe_townsfolk(), PackedStringArray(["Fixture — Villager · 0 hearts", "  Now: Fixture Home · Supper"]))
	assert_true(PauseMenu.get_page_ids().has(&"townsfolk"), "the module adds the page")
	_profile.schedule_entries = []
	assert_eq(state.describe_day(_profile), PackedStringArray(), "nothing to tell of one without a schedule, talk or gift")
	WorldClock.set_time(14, 10 * 60)
	assert_eq(state.describe_day(_profile), PackedStringArray(["Their birthday: a gift counts twice"]), "a birthday today")

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

func test_the_hearts_are_counted_in_the_players_language() -> void:
	assert_eq(tr_n("%d heart", "%d hearts", 1) % 1, "1 heart")
	assert_eq(tr_n("%d heart", "%d hearts", 3) % 3, "3 hearts")
	TranslationServer.set_locale("zh_CN")
	var chinese := tr_n("%d heart", "%d hearts", 3) % 3
	TranslationServer.set_locale(GameLocales.SOURCE)
	assert_eq(chinese, "3 颗心", "Chinese has one form for every count")

## A giftable item (a gift is no tool or seed).
func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = ItemData.Kind.GIFT
	return item

static func _location(id: StringName, display_name: String) -> WorldLocationData:
	var location := WorldLocationData.new()
	location.id = id
	location.display_name = display_name
	return location

static func _entry(minute: int, location_id: StringName, activity: String) -> NpcScheduleEntry:
	var entry := NpcScheduleEntry.new()
	entry.minute_of_day = minute
	entry.location_id = location_id
	entry.activity = activity
	return entry
