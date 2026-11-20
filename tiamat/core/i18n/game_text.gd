class_name GameText
extends RefCounted

## Text the player reads, put together the way their language does: a list
## of names or changes (`list()`), which every layer joins through here rather
## than with a separator of its own, and a line of parts split by dots
## (`parts()`), which wraps after a dot, never before one; a menu that shows
## lines put together elsewhere, in a translated text too ("%s · %d/%d
## donated"), keeps their dots the same way (`keep_dots()`).

## The separator of a list, a translation key of the core's catalog.
const LIST_SEPARATOR := ", "

## `parts` as one list the player reads in their language: "Gel, Ore" in
## English, "凝胶、矿石" in Chinese (the core's catalog translates
## `LIST_SEPARATOR`).
static func list(parts: PackedStringArray) -> String:
	return String(TranslationServer.translate(LIST_SEPARATOR)).join(parts)

## The separator between the parts of a line ("Spring · 06:00–20:00 · Rain"):
## the space before its dot does not break, so a line that wraps ends on the
## dot and the next starts with a part, never with the dot.
const PART_SEPARATOR := "\u00a0· "
## A space a line never breaks at.
const NO_BREAK_SPACE := "\u00a0"

## `parts` as one line split by `PART_SEPARATOR`. With `whole`, a line that
## wraps breaks only between parts, so a short one ("Attack 6") stays together.
static func parts(parts: PackedStringArray, whole := false) -> String:
	var shown := PackedStringArray()
	for part: String in parts:
		shown.append(part.replace(" ", NO_BREAK_SPACE) if whole else part)
	return PART_SEPARATOR.join(shown)

## `text` with each dot that splits its parts (" · ") made `PART_SEPARATOR`,
## so a label that wraps it never starts a line with the dot.
static func keep_dots(text: String) -> String:
	return text.replace(" · ", PART_SEPARATOR)
