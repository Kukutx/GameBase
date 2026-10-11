extends GutTest

## Farm1's achievements, unlocked by its triggers (`game/data/triggers/`) from
## what the player does, and kept in the player's profile across saves.

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

func _harvest(quantity: int) -> void:
	GameTriggers.fire(&"LifesimEvents.crop_harvested", {"crop_id": &"turnip", "item_id": &"turnip", "quantity": quantity})
