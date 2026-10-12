extends GutTest

## The checks the NPC and social module's kinds of content make of themselves,
## on broken entries the test builds.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_npcs_and_heart_events_report_malformed_numbers_and_schedules_without_crashing() -> void:
	var meadow := WorldLocationData.new()
	meadow.id = &"fixture_meadow"
	var schedule := NpcScheduleEntry.new()
	schedule.location_id = &"fixture_meadow"
	schedule.days_of_week = PackedInt32Array([8])
	schedule.seasons = PackedStringArray(["Monsoon"])
	schedule.allowed_weather = PackedStringArray(["Hail"])
	var npc := NpcProfileData.new()
	npc.id = &"fixture_bad_npc"
	npc.home_location_id = &"fixture_meadow"
	npc.default_location_id = &"fixture_meadow"
	npc.dialogue_titles_by_hearts = {"oops": "bad", 99: "too_high", 2: {"bad": true}}
	npc.schedule_entries = [schedule]
	npc.birthday_season = "Monsoon"
	npc.birthday_day = 40
	assert_eq(npc.get_dialogue_title("fallback", 10), "fallback")
	var heart := HeartEventData.new()
	heart.id = &"fixture_bad_heart"
	heart.npc_id = &"fixture_bad_npc"
	heart.dialogue_title = "bad"
	heart.location_id = &"fixture_meadow"
	heart.required_hearts = 99
	heart.start_minute = 600
	heart.end_minute = 600
	var entries: Array = [meadow, npc, heart]
	var registry := ContentFixture.use(self, entries)
	var problems := PackedStringArray()
	for entry: ContentEntry in entries:
		problems.append_array(registry.find_entry_problems(entry))
	var joined := "\n".join(problems)
	assert_string_contains(joined, "npc 'fixture_bad_npc' dialogue threshold 'oops' is not an integer")
	assert_string_contains(joined, "npc 'fixture_bad_npc' dialogue threshold 99 is outside heart range")
	assert_string_contains(joined, "npc 'fixture_bad_npc' dialogue threshold 2 has an invalid title")
	assert_string_contains(joined, "npc 'fixture_bad_npc' schedule has invalid weekday 8")
	assert_string_contains(joined, "npc 'fixture_bad_npc' schedule has unknown season 'Monsoon'")
	assert_string_contains(joined, "npc 'fixture_bad_npc' schedule has unknown weather 'Hail'")
	assert_string_contains(joined, "npc 'fixture_bad_npc' has unknown birthday season 'Monsoon'")
	assert_string_contains(joined, "npc 'fixture_bad_npc' has invalid birthday day 40")
	assert_string_contains(joined, "heart event 'fixture_bad_heart' has invalid heart requirement 99")
	assert_string_contains(joined, "heart event 'fixture_bad_heart' has an invalid time window")

func test_an_npc_without_a_birthday_is_well_formed_and_never_has_one() -> void:
	var npc := NpcProfileData.new()
	npc.id = &"fixture_npc"
	npc.display_name = "Fixture"
	var registry := ContentFixture.use(self, [npc])
	assert_eq(registry.find_entry_problems(npc), PackedStringArray())
	for day: int in [1, 14, 29, 113]:
		assert_false(npc.is_birthday(day), "day %d" % day)
