extends GutTest

## The condition keys the life-sim module registers (`LifesimRules`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func before_each() -> void:
	var fair := CalendarEventData.new()
	fair.id = &"fixture_fair"
	fair.display_name = "Fair"
	fair.seasons = PackedStringArray(["Spring"])
	fair.day_of_season = 9
	fair.start_minute = 9 * 60
	fair.end_minute = 17 * 60
	ContentFixture.use(self, [fair])

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB

func test_event_active_follows_the_calendar_at_the_day_and_minute_asked_about() -> void:
	assert_true(GameRules.has_condition(&"EVENT_ACTIVE"))
	assert_true(GameRules.check("EVENT_ACTIVE fixture_fair", {"day": 9, "minute_of_day": 9 * 60}))
	assert_false(GameRules.check("EVENT_ACTIVE fixture_fair", {"day": 9, "minute_of_day": 17 * 60}), "the event ends at its end minute")
	assert_false(GameRules.check("EVENT_ACTIVE fixture_fair", {"day": 10, "minute_of_day": 12 * 60}))
	assert_true(GameRules.check("!EVENT_ACTIVE fixture_fair", {"day": 37, "minute_of_day": 12 * 60}), "summer day 9 is not the spring fair")

func test_event_active_names_a_calendar_event() -> void:
	assert_eq(GameRules.validate_query("EVENT_ACTIVE fixture_fair"), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_query("EVENT_ACTIVE fixture_parade")), "unknown calendar_event 'fixture_parade'")

func test_milestone_claimed_names_a_collection_milestone() -> void:
	var milestone := CollectionMilestoneData.new()
	milestone.id = &"fixture_archive"
	ContentFixture.use(self, [milestone])
	assert_eq(GameRules.validate_query("!MILESTONE_CLAIMED fixture_archive"), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_query("MILESTONE_CLAIMED fixture_garden")), "unknown collection_milestone 'fixture_garden'")
