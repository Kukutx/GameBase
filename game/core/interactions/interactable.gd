class_name Interactable
extends Area2D

signal interacted(actor: Node)

@export var prompt_text: String = "Interact"
@export var enabled: bool = true

func interact(actor: Node) -> void:
	if not enabled:
		return
	interacted.emit(actor)
