class_name GameFont
extends RefCounted

## The font the core ships (`PATH`): Latin, Chinese punctuation, the characters
## of GB 2312 and those the repository's text uses (`tools/subset_font.js`),
## since a web build has no system fonts to fall back on. `GameSettings` makes
## it the font of the engine's default theme as the game starts (`use()`), the
## one every text shows in unless the game's theme names another. It is loaded
## then rather than named by a theme, which the engine reads before a fresh
## checkout has imported the font.

const PATH := "res://gamebase/core/ui/fonts/noto_sans_sc.woff2"

## Makes `font` what text shows in unless a theme names another: the default
## theme's font, the base of the bold and italic fonts it makes of that, and
## the font of last resort (`ThemeDB.fallback_font`).
static func use(font: Font) -> void:
	var theme := ThemeDB.get_default_theme()
	var replaced := theme.default_font
	theme.default_font = font
	for type: StringName in theme.get_font_type_list():
		for font_name: StringName in theme.get_font_list(type):
			var variation := theme.get_font(font_name, type) as FontVariation
			if variation != null and variation.base_font == replaced:
				var based := variation.duplicate() as FontVariation
				based.base_font = font
				theme.set_font(font_name, type, based)
	ThemeDB.fallback_font = font
