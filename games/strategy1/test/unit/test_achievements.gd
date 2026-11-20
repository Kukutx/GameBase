extends GutTest

## Iron Banners' achievements, unlocked by its triggers (`game/data/triggers/`)
## as the player wins a battle and counts every raider defeated, and kept in
## the player's profile across saves.

const TEST_PATH := "user://test_strategy1_achievements/profile.json"

var _saved_path: String
var _saved_profile: Dictionary

func before_each() -> void:
	_saved_path = GameProfile.profile_path
	_saved_profile = GameProfile.to_save_data()
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})

func after_each() -> void:
	GameProfile.load_save_data(_saved_profile)
	GameProfile.profile_path = _saved_path
	for path: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_winning_both_battles_unlocks_each_and_then_the_banner_bearer() -> void:
	GameTriggers.fire(&"TacticsEvents.battle_ended", {"battle_map_id": &"border_ford", "won": false})
	assert_false(GameProfile.is_unlocked(&"ford_held"), "a lost battle holds nothing")
	GameTriggers.fire(&"TacticsEvents.battle_ended", {"battle_map_id": &"border_ford", "won": true})
	assert_true(GameProfile.is_unlocked(&"ford_held"))
	assert_false(GameProfile.is_unlocked(&"banner_bearer"))
	GameTriggers.fire(&"RtsEvents.battle_ended", {"rts_map_id": &"hill_pass", "won": true})
	assert_true(GameProfile.is_unlocked(&"pass_held"))
	assert_true(GameProfile.is_unlocked(&"banner_bearer"), "both battles won")

func test_raiders_defeated_in_every_battle_count_toward_veteran() -> void:
	# As if earlier battles had defeated 48.
	GameProfile.set_flag(&"foes_defeated", 48)
	GameTriggers.fire(&"TacticsEvents.foe_defeated", {"battle_unit_id": &"raider"})
	assert_eq(GameProfile.get_progress(&"veteran"), 49)
	assert_false(GameProfile.is_unlocked(&"veteran"))
	GameTriggers.fire(&"RtsEvents.foe_defeated", {"rts_unit_id": &"raider"})
	assert_true(GameProfile.is_unlocked(&"veteran"))
