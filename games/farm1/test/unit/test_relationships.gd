extends GutTest

## Farm1's NPC birthdays. How gifts are scored, doubled on a birthday and kept
## as friendship is tested with the NPC social module.

func test_mira_birthday_is_spring_fourteen() -> void:
	var profile := NpcProfileData.find(&"mira")
	assert_not_null(profile)
	if profile == null:
		return
	assert_true(profile.is_birthday(14))
	assert_false(profile.is_birthday(13))
	assert_false(profile.is_birthday(15))
	assert_false(profile.is_birthday(14 + GameCalendar.current().days_per_season), "Summer 14 is not her birthday")
