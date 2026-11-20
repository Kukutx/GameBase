class_name GameLocales
extends RefCounted

## The languages a game speaks: English, its source (`SOURCE`), and every
## locale it registers a translation catalog for (`supported()`), each named in
## its own language for the language picker (`display_name()`). The first
## launch speaks the one nearest the system's (`nearest()`, `system`);
## `GameSettings.locale` holds the player's choice.

## Source text is English.
const SOURCE := "en"
## Each language's name in that language.
const NAMES := {
	"de": "Deutsch",
	"en": "English",
	"es": "Español",
	"fr": "Français",
	"it": "Italiano",
	"ja": "日本語",
	"ko": "한국어",
	"pl": "Polski",
	"pt_BR": "Português (Brasil)",
	"ru": "Русский",
	"tr": "Türkçe",
	"zh_CN": "简体中文",
	"zh_TW": "繁體中文",
}

## The system's language as the game starts (`OS.get_locale()`); a test run
## sets the source language here, so no test depends on the machine's.
static var system := OS.get_locale()

## The source locale followed by every locale the game registers a
## translation for, in order.
static func supported() -> PackedStringArray:
	var result := PackedStringArray([SOURCE])
	var loaded := TranslationServer.get_loaded_locales()
	loaded.sort()
	for locale: String in loaded:
		if not result.has(locale):
			result.append(locale)
	return result

## Whether the game speaks `locale`.
static func is_supported(locale: Variant) -> bool:
	return locale is String and supported().has(locale)

## The locale of `among` nearest `system_locale` (an `OS.get_locale()`): the
## same one, else one of the same language (a Traditional Chinese system reads
## Simplified Chinese before English), else the source language.
static func nearest(system_locale: String, among: PackedStringArray) -> String:
	var found := SOURCE
	var found_score := 0
	for candidate: String in among:
		var score := TranslationServer.compare_locales(system_locale, candidate)
		if score > found_score:
			found = candidate
			found_score = score
	return found

## `locale`'s name in its own language (the engine's English name for one
## `NAMES` lacks).
static func display_name(locale: String) -> String:
	return String(NAMES.get(locale, TranslationServer.get_locale_name(locale)))
