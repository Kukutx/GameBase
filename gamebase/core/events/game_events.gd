class_name GlobalGameEvents
extends Node

## The core's notifications: the short status line (toast) the game's HUD
## shows, the hints the player reads once (`HintData`) and the menus opening
## and closing. What happens in a
## module's systems is announced on that module's own `<Module>Events`
## autoload (`LifesimEvents.crop_harvested`).

signal toast_requested(message: String)
## A hint for the player, translated and its controls named
## (`HintData.get_message()`); the rule action `SHOW_HINT` sends it.
signal hint_requested(message: String)
## A menu over the world opened (`MenuLayer`, the settings); `menu_id` is its
## name (`MenuLayer.menu_id`).
signal menu_opened(menu_id: StringName)
## A menu closed.
signal menu_closed(menu_id: StringName)

func toast(message: String) -> void:
	if message.is_empty():
		return
	toast_requested.emit(tr(message))

func toastf(template: String, args: Array[Variant] = []) -> void:
	if template.is_empty():
		return
	var resolved: Array[Variant] = []
	for arg: Variant in args:
		if arg is String or arg is StringName:
			resolved.append(tr(String(arg)))
		else:
			resolved.append(arg)
	toast_requested.emit(tr(template) % resolved)
