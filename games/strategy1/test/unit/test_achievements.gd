extends GutTest

## Iron Banners' achievements, unlocked by its triggers (`game/data/triggers/`)
## as the player wins a battle and counts every raider defeated, and kept in
## the player's profile across saves.

const TEST_PATH := "user://test_strategy1_achievements/profile.json"

var _saved_path: String
var _saved_profile: Dictionary
var _saved_options: GameOptions

func before_each() -> void:
	_saved_options = GameSettings.options
	GameSettings.options = GameOptions.of_running_game()
	_saved_path = GameProfile.profile_path
	_saved_profile = GameProfile.to_save_data()
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})

func after_each() -> void:
	GameSettings.options = _saved_options
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
	assert_eq(RecordData.find(&"battles_won").get_value(), 2, "the record counts the wins, not the loss")

func test_a_win_against_strong_foes_goes_against_the_odds() -> void:
	GameTriggers.fire(&"RtsEvents.battle_ended", {"rts_map_id": &"hill_pass", "won": true})
	assert_false(GameProfile.is_unlocked(&"against_the_odds"), "on standard foes")
	GameSettings.options.set_value(RtsBattleGame.FOE_STRENGTH_OPTION, "Strong")
	GameTriggers.fire(&"RtsEvents.battle_ended", {"rts_map_id": &"hill_pass", "won": false})
	assert_false(GameProfile.is_unlocked(&"against_the_odds"), "a loss")
	GameTriggers.fire(&"RtsEvents.battle_ended", {"rts_map_id": &"hill_pass", "won": true})
	assert_true(GameProfile.is_unlocked(&"against_the_odds"))

func test_raiders_defeated_in_every_battle_count_toward_veteran() -> void:
	# As if earlier battles had defeated 48.
	GameProfile.set_flag(&"foes_defeated", 48)
	GameTriggers.fire(&"TacticsEvents.foe_defeated", {"battle_unit_id": &"raider"})
	assert_eq(GameProfile.get_progress(&"veteran"), 49)
	assert_false(GameProfile.is_unlocked(&"veteran"))
	GameTriggers.fire(&"RtsEvents.foe_defeated", {"rts_unit_id": &"raider"})
	assert_true(GameProfile.is_unlocked(&"veteran"))

func test_the_second_battle_of_each_station_has_its_own_achievement() -> void:
	GameTriggers.fire(&"TacticsEvents.battle_ended", {"battle_map_id": &"old_mill", "won": false})
	assert_false(GameProfile.is_unlocked(&"mill_taken"), "a lost battle takes nothing")
	GameTriggers.fire(&"TacticsEvents.battle_ended", {"battle_map_id": &"old_mill", "won": true})
	assert_true(GameProfile.is_unlocked(&"mill_taken"))
	assert_false(GameProfile.is_unlocked(&"ford_held"), "the mill is not the ford")
	GameTriggers.fire(&"RtsEvents.battle_ended", {"rts_map_id": &"raider_camp", "won": true})
	assert_true(GameProfile.is_unlocked(&"camp_stormed"))
	assert_false(GameProfile.is_unlocked(&"pass_held"))
