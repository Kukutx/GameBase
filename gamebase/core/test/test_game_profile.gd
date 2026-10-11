extends GutTest

## The player's profile (`GameProfileService`), which outlives every save, and
## its rule keys.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TEST_PATH := "user://test_profile/profile.json"
const BLOCKED_DIRECTORY := "user://test_profile/blocked"

var _saved_path: String
var _saved: Dictionary
var _profiles: Array[GameProfileService] = []

func before_each() -> void:
	_remove_test_files()
	_saved_path = GameProfile.profile_path
	_saved = GameProfile.to_save_data()
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})
	ContentFixture.use(self, [_achievement(&"fixture_first_step", false), _achievement(&"fixture_secret", true)])

func after_each() -> void:
	ContentRegistry.active = ContentDB
	GameProfile.load_save_data(_saved)
	GameProfile.profile_path = _saved_path
	# Freed, a profile writes what it has not yet; then the files go.
	for profile: GameProfileService in _profiles:
		if is_instance_valid(profile):
			profile.free()
	_profiles.clear()
	_remove_test_files()

func test_an_achievement_unlocks_once_and_is_kept_in_the_profile_file() -> void:
	var profile := _profile()
	watch_signals(profile)
	assert_true(profile.unlock(&"fixture_first_step"))
	assert_true(profile.unlock(&"fixture_first_step"), "unlocking it again changes nothing")
	assert_signal_emit_count(profile, "achievement_unlocked", 1)
	assert_true(profile.is_unlocked(&"fixture_first_step"))
	assert_gt(profile.get_unlocked_time(&"fixture_first_step"), 0)
	assert_false(profile.unlock(&"fixture_missing"), "an id the content does not have")
	assert_true(profile.write_now())
	var reloaded := _profile()
	assert_eq(reloaded.get_unlocked(), [&"fixture_first_step"])
	assert_eq(reloaded.get_unlocked_time(&"fixture_first_step"), profile.get_unlocked_time(&"fixture_first_step"))

func test_flags_keep_booleans_and_counters_through_the_file() -> void:
	var profile := _profile()
	profile.set_flag(&"fixture_seen_ending", true)
	assert_eq(profile.add_int(&"fixture_runs", 2), 2)
	assert_eq(profile.add_int(&"fixture_runs", 3), 5)
	profile.set_flag(&"fixture_broken", 1.5)
	assert_true(profile.write_now())
	var reloaded := _profile()
	assert_true(reloaded.get_bool(&"fixture_seen_ending"))
	assert_eq(reloaded.get_int(&"fixture_runs"), 5)
	assert_eq(typeof(reloaded.to_save_data()["flags"]["fixture_runs"]), TYPE_INT, "a counter comes back an integer")
	assert_false(reloaded.to_save_data()["flags"].has("fixture_broken"), "only booleans and integers are flags")

func test_changes_are_written_once_before_the_next_frame() -> void:
	var profile := _profile()
	profile.unlock(&"fixture_first_step")
	profile.add_int(&"fixture_runs", 1)
	assert_false(FileAccess.file_exists(TEST_PATH), "nothing is written while changes come in")
	await get_tree().process_frame
	assert_true(FileAccess.file_exists(TEST_PATH))
	assert_true(_profile().is_unlocked(&"fixture_first_step"))

func test_a_broken_or_other_version_file_gives_an_empty_profile() -> void:
	_write(TEST_PATH, "{ not json")
	assert_eq(_profile().get_unlocked(), [])
	_write(TEST_PATH, JSON.stringify({"profile_version": 99, "achievements": {"fixture_first_step": 5}}))
	assert_false(_profile().is_unlocked(&"fixture_first_step"))
	_write(TEST_PATH, JSON.stringify({"profile_version": 1, "achievements": {"fixture_first_step": 5}}))
	assert_eq(_profile().get_unlocked_time(&"fixture_first_step"), 5)

func test_a_profile_keeps_only_what_is_well_formed_and_current_content() -> void:
	_write(TEST_PATH, JSON.stringify({"profile_version": 1,
		"achievements": {"fixture_first_step": 7.0, "fixture_secret": 0, "fixture_removed": 9},
		"flags": {"fixture_runs": 4.0, "fixture_half": 60000.5, "fixture_seen": true, "": 1, "fixture_text": "yes"}}))
	var profile := _profile()
	assert_eq(profile.get_unlocked(), [&"fixture_first_step"], "an unlock without its time, or of an achievement the content no longer has, is left out")
	assert_eq(profile.to_save_data()["flags"], {"fixture_runs": 4, "fixture_seen": true})
	_write(TEST_PATH, JSON.stringify({"profile_version": 1.5, "achievements": {"fixture_first_step": 7}}))
	assert_eq(_profile().get_unlocked(), [], "a version is a whole number")

func test_a_change_that_could_not_be_written_is_written_with_the_next_try() -> void:
	# A file where the profile's folder should be: nothing can be written.
	_write(BLOCKED_DIRECTORY, "")
	var profile := _profile()
	watch_signals(profile)
	profile.profile_path = BLOCKED_DIRECTORY.path_join("profile.json")
	profile.unlock(&"fixture_first_step")
	assert_false(profile.write_now())
	assert_false(profile.write_now())
	assert_signal_emit_count(profile, "write_failed", 1, "the player hears of it once")
	profile.profile_path = TEST_PATH
	assert_true(profile.write_now(), "the unlock is still waiting to be written")
	assert_true(_profile().is_unlocked(&"fixture_first_step"))

func test_a_profile_a_crash_left_unrenamed_is_read() -> void:
	_write(TEST_PATH + ".tmp", JSON.stringify({"profile_version": 1, "achievements": {"fixture_first_step": 7}}))
	assert_eq(_profile().get_unlocked_time(&"fixture_first_step"), 7)

func test_resetting_forgets_everything() -> void:
	var profile := _profile()
	profile.unlock(&"fixture_first_step")
	profile.set_flag(&"fixture_seen_ending", true)
	profile.reset_profile()
	assert_eq(profile.get_unlocked(), [])
	assert_false(profile.get_bool(&"fixture_seen_ending"))

func test_content_reads_and_changes_the_profile_through_rule_keys() -> void:
	assert_true(GameRules.run_actions(PackedStringArray(["UNLOCK_ACHIEVEMENT fixture_first_step", "ADD_PROFILE_FLAG fixture_runs 3", "SET_PROFILE_FLAG fixture_seen_ending"])))
	assert_true(GameRules.check("ACHIEVEMENT_UNLOCKED fixture_first_step, PROFILE_FLAG_AT_LEAST fixture_runs 3, PROFILE_FLAG fixture_seen_ending"))
	assert_false(GameRules.check("ACHIEVEMENT_UNLOCKED fixture_secret"))
	var problems := "\n".join(GameRules.validate_actions(PackedStringArray(["UNLOCK_ACHIEVEMENT fixture_missing"])))
	assert_string_contains(problems, "unknown achievement 'fixture_missing'")

func test_an_achievement_names_itself() -> void:
	var nameless := AchievementData.new()
	nameless.id = &"fixture_nameless"
	var registry := ContentFixture.use(self, [nameless])
	var problems := "\n".join(registry.find_entry_problems(nameless))
	assert_string_contains(problems, "achievement 'fixture_nameless' has no display name")
	assert_string_contains(problems, "achievement 'fixture_nameless' has no description")

func _achievement(id: StringName, hidden: bool) -> AchievementData:
	var achievement := AchievementData.new()
	achievement.id = id
	achievement.display_name = String(id)
	achievement.description = "Fixture"
	achievement.hidden = hidden
	return achievement

# A profile of its own on the test file, read when it enters the tree.
func _profile() -> GameProfileService:
	var profile := GameProfileService.new()
	profile.profile_path = TEST_PATH
	add_child_autofree(profile)
	_profiles.append(profile)
	return profile

func _remove_test_files() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", BLOCKED_DIRECTORY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
