class_name GameText
extends RefCounted

## Text the player reads, put together the way their language does: a list
## of names or changes (`list()`), which every layer joins through here rather
## than with a separator of its own.

## The separator of a list, a translation key of the core's catalog.
const LIST_SEPARATOR := ", "

## `parts` as one list the player reads in their language: "Gel, Ore" in
## English, "凝胶、矿石" in Chinese (the core's catalog translates
## `LIST_SEPARATOR`).
static func list(parts: PackedStringArray) -> String:
	return String(TranslationServer.translate(LIST_SEPARATOR)).join(parts)
