extends GutTest

## Farm1's trigger that turns talking into social experience
## (`game/data/triggers/social_talk_xp.tres`): only the first talk with an NPC
## each day counts, so talking again and again gives nothing more.

var _saved_skills: Dictionary

func before_each() -> void:
	_saved_skills = Skills.to_save_data()

func after_each() -> void:
	Skills.load_save_data(_saved_skills)

func test_only_the_first_talk_of_the_day_gives_social_experience() -> void:
	var before := Skills.get_xp(&"social")
	GameTriggers.fire(&"NpcSocialEvents.npc_talked", {"npc_id": &"mira", "first_today": true})
	var after_first := Skills.get_xp(&"social")
	assert_gt(after_first, before)
	GameTriggers.fire(&"NpcSocialEvents.npc_talked", {"npc_id": &"mira", "first_today": false})
	assert_eq(Skills.get_xp(&"social"), after_first)
