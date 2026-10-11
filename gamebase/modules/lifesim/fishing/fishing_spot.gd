class_name FishingSpot
extends Interactable

@export var location_id: StringName
@export var required_rod_id: StringName = &"fishing_rod"
@export_range(0, 100, 1) var energy_cost := 4

func _ready() -> void:
	prompt_text = "Fish"

func interact(actor: Node) -> void:
	if location_id == &"":
		var location := ContentDB.get_current_location(get_tree())
		if location != null:
			location_id = location.id
	if required_rod_id != &"" and not InventoryState.has_item(required_rod_id, 1):
		GameEvents.toast("You need a fishing rod")
		return
	if location_id == &"":
		GameEvents.toast("This fishing spot has no location data")
		return
	if DisplayServer.get_name() == "headless":
		FishingState.try_fish(location_id, energy_cost)
	else:
		FishingState.start_cast(location_id, energy_cost)
	super.interact(actor)
