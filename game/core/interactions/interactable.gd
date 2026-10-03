class_name Interactable
extends Area2D

signal interacted(actor: Node)

@export var prompt_text: String = "Interact"
@export var enabled: bool = true

var _prompt_args: Array[Variant] = []

func set_prompt(template: String, args: Array[Variant] = []) -> void:
	prompt_text = template
	_prompt_args = args.duplicate()

func get_prompt_text() -> String:
	var translated := tr(prompt_text)
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
