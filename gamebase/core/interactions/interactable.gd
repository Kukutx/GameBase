class_name Interactable
extends Area2D

signal interacted(actor: Node)
## Emitted when what the prompt says changes (`prompt_text`, `set_prompt()`).
signal prompt_changed

## What the prompt says, without arguments; `set_prompt()` sets it with them.
@export var prompt_text: String = "Interact":
	get:
		return _prompt_text
	set(value):
		set_prompt(value)
@export var enabled: bool = true

var _prompt_text := "Interact"
var _prompt_args: Array[Variant] = []

## Sets what the prompt says: `template`, translated when it is shown, with
## `args` formatted into it.
func set_prompt(template: String, args: Array[Variant] = []) -> void:
	if _prompt_text == template and _prompt_args == args:
		return
	_prompt_text = template
	_prompt_args = args.duplicate()
	prompt_changed.emit()

func get_prompt_text() -> String:
	var translated := tr(_prompt_text)
	if _prompt_args.is_empty():
		return translated
	var resolved: Array[Variant] = []
	for arg: Variant in _prompt_args:
		if arg is String or arg is StringName:
			resolved.append(tr(String(arg)))
		else:
			resolved.append(arg)
	return translated % resolved

func interact(actor: Node) -> void:
	if not enabled:
		return
	interacted.emit(actor)
