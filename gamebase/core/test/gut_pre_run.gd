extends GutHookScript

## What every game's test run sets up before its first test (each game's
## `.gutconfig.json` names this hook): a run does not inherit the developer's
## language or settings, and does not touch their settings or profile.

const TEST_SETTINGS_PATH := "user://test_run/settings.json"
const TEST_PROFILE_PATH := "user://test_run/profile.json"

func run() -> void:
	# Tests compare text against the English source strings, and start from
	# the default settings, which they write to a file of the run's own.
	GameSettings.settings_path = TEST_SETTINGS_PATH
	GameSettingsService.system_locale = GameSettingsService.SOURCE_LOCALE
	GameSettings.locale = "en"
	GameSettings.reset_all()
	# Triggers on real content unlock achievements while tests play; they go
	# to a profile of the run's own, which starts empty.
	for path: String in [TEST_PROFILE_PATH, TEST_PROFILE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameProfile.profile_path = TEST_PROFILE_PATH
	GameProfile.load_profile()
	# Travels change scenes behind the transition as in play, without its fades.
	Transition.fade_seconds = 0.0
