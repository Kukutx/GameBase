extends GutTest

## The game's text shows in its theme's font: every character of every
## translation the game registers, and the name of each language it offers, is
## in the font a label draws with, the core's (`GameSettingsService.FONT_PATH`)
## unless the game's theme names another. A web build has no system fonts to
## fall back on, so a missing character would show as a box.

func test_the_theme_font_has_every_character_of_the_translations() -> void:
	var font := _theme_font()
	var missing := {}
	for path: String in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
		var translation := load(path) as Translation
		assert_not_null(translation, path)
		if translation == null:
			continue
		for message: String in translation.get_translated_message_list():
			for character: String in _missing_characters(font, message):
				missing[character] = path.get_file()
	assert_eq(missing, {}, "characters the font lacks, by the catalog that uses them")

func test_the_theme_font_has_the_name_of_each_language() -> void:
	var font := _theme_font()
	for locale: String in GameSettings.get_supported_locales():
		var display_name := GameSettings.get_locale_display_name(locale)
		assert_eq(_missing_characters(font, display_name), PackedStringArray(), display_name)

func test_labels_and_rich_text_draw_in_the_core_font_unless_the_theme_names_one() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null or theme.default_font == null:
		assert_eq(_theme_font().resource_path, GameSettingsService.FONT_PATH)
	var rich := RichTextLabel.new()
	add_child_autofree(rich)
	for font_name: StringName in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font", &"mono_font"]:
		for text: String in ["GameBase", "简体中文", "存档已保存。", "「体力」…！"]:
			assert_eq(_missing_characters(rich.get_theme_font(font_name), text), PackedStringArray(), "%s: %s" % [font_name, text])

# The font a label in the game draws with.
func _theme_font() -> Font:
	var label := Label.new()
	add_child_autofree(label)
	return label.get_theme_font(&"font")

static func _missing_characters(font: Font, text: String) -> PackedStringArray:
	var missing := PackedStringArray()
	for index: int in text.length():
		var code := text.unicode_at(index)
		if code > 0x20 and code != 0xA0 and code != 0x3000 and not font.has_char(code) and not missing.has(text[index]):
			missing.append(text[index])
	return missing
