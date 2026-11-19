class_name ToolUpgradeStation
extends Node2D

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("tool_upgrade_menu")
	if menu != null and menu.has_method("open"):
		menu.call("open")
	else:
		GameEvents.toast("Forge menu is unavailable")
