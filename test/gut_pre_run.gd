extends GutHookScript

# Tests compare text against the English source strings, so a run does not
# inherit the language saved in the developer's own settings.
func run() -> void:
	GameSettings.locale = "en"
	TranslationServer.set_locale("en")
