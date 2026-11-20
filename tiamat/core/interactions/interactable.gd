class_name Interactable
extends Area2D

signal interacted(actor: Node)
## Emitted when what the prompt says changes (`prompt_text`, `set_prompt()`).
signal prompt_changed
## Emitted when the player's `InteractionController` takes it in focus (the
## nearest it can use in reach) or lets it go (`is_focused()`).
signal focus_changed(focused: bool)

## What the prompt says, without arguments; `set_prompt()` sets it with them.
@export var prompt_text: String = "Interact":
	get:
		return _prompt_text
	set(value):
		set_prompt(value)
@export var enabled: bool = true

var _prompt_text := "Interact"
var _prompt_args: Array[Variant] = []
var _focused := false

## Whether the player stands at it: their `InteractionController` has it in
## focus, so a press of the control uses it. A node shows what it tells only
## then (a villager's doings), so a crowd of them does not cover the view.
func is_focused() -> bool:
	return _focused

## Takes it in focus or lets it go; the `InteractionController` calls it.
func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	focus_changed.emit(value)

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
