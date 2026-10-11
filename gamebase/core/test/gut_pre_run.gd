extends GutHookScript

## What every game's test run sets up before its first test (each game's
## `.gutconfig.json` names this hook): a run does not inherit the developer's
## language, and does not touch their profile.

const TEST_PROFILE_PATH := "user://test_run/profile.json"

func run() -> void:
	# Tests compare text against the English source strings.
	GameSettings.locale = "en"
	TranslationServer.set_locale("en")
	# Triggers on real content unlock achievements while tests play; they go
	# to a profile of the run's own, which starts empty.
	for path: String in [TEST_PROFILE_PATH, TEST_PROFILE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameProfile.profile_path = TEST_PROFILE_PATH
	GameProfile.load_profile()
