class_name AnimalLedger
extends Node2D

## The location whose animals the ledger manages; empty: the location it is in.
@export var location_id: StringName
@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("animal_management_menu") as AnimalManagementMenu
	if menu == null:
		GameEvents.toast("Animal ledger UI is unavailable")
		return
	var managed := location_id
	if managed == &"":
		var location := ContentDB.get_current_location(get_tree())
		managed = location.id if location != null else &""
	menu.open(managed)
