class_name AnimalLedger
extends Node2D

@export var location_id: StringName = &"starter_town"
@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("animal_management_menu") as AnimalManagementMenu
	if menu == null:
		GameEvents.toast("Animal ledger UI is unavailable")
		return
	menu.open(location_id)
