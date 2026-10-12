class_name HintData
extends ContentEntry

## A tip the player reads once: how to move, that a sign can be read, what a
## new menu does. Content shows one with the action `SHOW_HINT <id>`, usually
## from a trigger (`TriggerData`) on what makes it useful, and asks about one
## with the condition `HINT_SHOWN <id>`. The player's profile (`GameProfile`)
## keeps which hints showed, so a hint shows once across every save, and none
## shows while the player turns hints off (`GameSettings.hints`). The HUD shows
## them on a status line that shows hints (`StatusLine.shows_hints`).
##
## The text names a control by its action in braces, `{interact}`, which reads
## as the key or button that performs it on the device in use, and `{move}` as
## the movement controls (`InputPrompts`), so a hint follows the player's
## bindings and gamepad.

const KIND := &"hint"
## The placeholder that reads as the movement controls.
const MOVE := "move"

@export_multiline var text := ""

static var _placeholder := RegEx.create_from_string("\\{([a-z0-9_]+)\\}")

## The hint with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> HintData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as HintData

## The profile flag that says the hint with `hint_id` showed.
static func get_shown_flag(hint_id: StringName) -> StringName:
	return StringName("hint:%s" % hint_id)

## The text as the player reads it now: translated, each control named as the
## device in use performs it.
func get_message() -> String:
	var message := tr(text)
	var prompts := {}
	for name: String in get_controls(message):
		prompts[name] = InputPrompts.get_move_prompt() if name == MOVE else InputPrompts.get_action_prompt(StringName(name))
	return message.format(prompts)

## The controls `message` names in braces, in order, each once.
static func get_controls(message: String) -> PackedStringArray:
	var names := PackedStringArray()
	for found: RegExMatch in _placeholder.search_all(message):
		if not names.has(found.get_string(1)):
			names.append(found.get_string(1))
	return names

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if text.strip_edges().is_empty():
		problems.append("has no text")
	for name: String in get_controls(text):
		if name != MOVE and GameSettings.bindings.get_control(StringName(name)) == null:
			problems.append("names unknown control '%s'" % name)
	return problems
