class_name FishingSpot
extends Interactable

## Fishing needs a tool whose action is `TOOL_ACTION` in the inventory.

const TOOL_ACTION := &"fish"

@export var location_id: StringName
@export_range(0, 100, 1) var energy_cost := 4

func _ready() -> void:
	prompt_text = "Fish"

func interact(actor: Node) -> void:
	if location_id == &"":
		var location := WorldLocationData.find_current(get_tree())
		if location != null:
			location_id = location.id
	if not InventoryState.has_tool(TOOL_ACTION):
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

func find_scene_problems(_registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	if location != null and location_id != &"" and location_id != location.id:
		return PackedStringArray(["fishing spot '%s' references different location '%s'" % [name, location_id]])
	return PackedStringArray()
