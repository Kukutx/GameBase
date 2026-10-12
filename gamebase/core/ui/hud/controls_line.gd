class_name ControlsLine
extends HudLine

## The controls the player has at hand, named as they press them on the device
## in use, each with what it does: "WASD move · E use". A control is an action
## (`interact`), `move`, actions pressed as one (`quick_save/quick_load`) or a
## prompt a module names (`InputPrompts.get_prompt()`); one the player cannot
## press right now is left out.

## Control -> what it does, in the order shown.
@export var hints: Dictionary[StringName, String] = {
	&"move": "move",
	&"interact": "use",
	&"quick_save": "save",
	&"quick_load": "load",
}

func _watch() -> void:
	watch(InputPrompts.input_method_changed)
	watch(InputPrompts.prompts_changed)
	watch(GameSettings.controls_changed)

func _get_parts() -> PackedStringArray:
	var parts := PackedStringArray()
	for control: StringName in hints:
		var prompt := InputPrompts.get_prompt(control)
		if not prompt.is_empty():
			parts.append("%s %s" % [prompt, tr(hints[control])])
	return parts
