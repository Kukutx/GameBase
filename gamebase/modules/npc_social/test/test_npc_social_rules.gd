extends GutTest

## The condition and action keys the NPC social module registers
## (`NpcSocialRules`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func before_each() -> void:
	var profile := NpcProfileData.new()
	profile.id = &"fixture_npc"
	profile.display_name = "Fixture"
	ContentFixture.use(self, [profile])

func test_npc_keys_are_registered_and_checked_against_content() -> void:
	assert_true(GameRules.has_condition(&"HEARTS"))
	assert_true(GameRules.has_action(&"ADD_FRIENDSHIP"))
	assert_eq(GameRules.validate_query("HEARTS fixture_npc 2"), PackedStringArray())
	assert_eq(GameRules.validate_actions(PackedStringArray(["ADD_FRIENDSHIP fixture_npc 10"])), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("HEARTS fixture_npc lots, HEARTS no_such_npc 2"))
	assert_string_contains(problems, "'lots' is not an integer")
	assert_string_contains(problems, "unknown npc 'no_such_npc'")
