extends GutTest

## Farm1's achievements, unlocked by its triggers (`game/data/triggers/`) from
## what the player does, or by the profile as a counter reaches a goal, and
## kept in the player's profile across saves.

const TEST_PATH := "user://test_farm1_achievements/profile.json"

var _saved_path: String
var _saved_profile: Dictionary
var _saved_skills: Dictionary

func before_each() -> void:
	_saved_path = GameProfile.profile_path
	_saved_profile = GameProfile.to_save_data()
	_saved_skills = Skills.to_save_data()
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})

func after_each() -> void:
	GameProfile.load_save_data(_saved_profile)
	GameProfile.profile_path = _saved_path
	Skills.load_save_data(_saved_skills)
	for path: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_the_first_harvest_and_the_first_catch_unlock_achievements() -> void:
	_harvest(1)
	assert_true(GameProfile.is_unlocked(&"green_thumb"))
	assert_false(GameProfile.is_unlocked(&"angler"))
	GameTriggers.fire(&"LifesimEvents.fish_caught", {"fish_id": &"trout", "item_id": &"trout"})
	assert_true(GameProfile.is_unlocked(&"angler"))

func test_crops_harvested_in_every_save_count_toward_seasoned_farmer() -> void:
	# As if earlier saves had harvested 95 crops.
	GameProfile.set_flag(&"crops_harvested", 95)
	_harvest(4)
	assert_eq(GameProfile.get_int(&"crops_harvested"), 99)
	assert_false(GameProfile.is_unlocked(&"seasoned_farmer"))
	_harvest(1)
	assert_true(GameProfile.is_unlocked(&"seasoned_farmer"))

func test_fish_gifts_and_mining_in_every_save_count_toward_their_achievements() -> void:
	GameProfile.set_flag(&"fish_caught", 49)
	GameTriggers.fire(&"LifesimEvents.fish_caught", {"fish_id": &"trout", "item_id": &"trout"})
	assert_true(GameProfile.is_unlocked(&"master_angler"))
	GameProfile.set_flag(&"gifts_given", 29)
	GameTriggers.fire(&"NpcSocialEvents.gift_given", {"npc_id": &"mira", "item_id": &"turnip", "friendship_delta": 20})
	assert_true(GameProfile.is_unlocked(&"generous"))
	GameTriggers.fire(&"LifesimEvents.resource_mined", {"mining_node_id": &"stone_rock", "item_id": &"stone", "quantity": 3, "position": Vector2.ZERO})
	assert_eq(GameProfile.get_progress(&"prospector"), 3, "each stone of a rock counts")
	assert_false(GameProfile.is_unlocked(&"prospector"))

func test_the_game_menu_counts_a_locked_one_toward_its_goal() -> void:
	GameProfile.set_flag(&"crops_harvested", 95)
	var menu := (load("res://game/ui/game_menu.tscn") as PackedScene).instantiate()
	autofree(menu)
	var lines := "\n".join(menu.call(&"_achievement_lines") as PackedStringArray)
	assert_string_contains(lines, "Seasoned Farmer — Harvest 100 crops, counting every save. (95 / 100)")
	assert_string_contains(lines, "○ ???", "a hidden one shows nothing of itself")

func test_an_iridium_tool_unlocks_the_hidden_iridium_touch() -> void:
	GameTriggers.fire(&"ProgressionEvents.tool_upgraded", {"tool_upgrade_id": &"gold_hoe_upgrade", "result_item_id": &"gold_hoe"})
	assert_false(GameProfile.is_unlocked(&"iridium_touch"), "gold is not iridium")
	GameTriggers.fire(&"ProgressionEvents.tool_upgraded", {"tool_upgrade_id": &"iridium_sword_upgrade", "result_item_id": &"iridium_sword"})
	assert_true(GameProfile.is_unlocked(&"iridium_touch"))
	assert_true(AchievementData.find(&"iridium_touch").hidden)

func _harvest(quantity: int) -> void:
	GameTriggers.fire(&"LifesimEvents.crop_harvested", {"crop_id": &"turnip", "item_id": &"turnip", "quantity": quantity})
