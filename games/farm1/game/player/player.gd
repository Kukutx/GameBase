class_name GamePlayer
extends TopDownPlayer

## Farm1's player: walks, works the soil with the selected tool (its
## `FarmToolController`), attacks (its `MeleeAttack`) and uses what is near
## (its `InteractionController`), as a `TopDownPlayer`; picks a hotbar slot
## (its `HotbarInput`); gives the selected item as a gift and packs up a
## placed structure.

@onready var interaction_controller: InteractionController = $InteractionController

func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return
	if event.is_action_pressed("give_gift"):
		_give_selected_gift()
	elif event.is_action_pressed("remove_building"):
		_remove_focused_building()
	else:
		return
	get_viewport().set_input_as_handled()

func _give_selected_gift() -> void:
	var focused := interaction_controller.get_focused()
	if focused == null:
		GameEvents.toast("Stand near someone to give a gift")
		return
	var npc := focused.get_parent() as GameNpc
	if npc == null:
		GameEvents.toast("That is not someone you can gift")
		return
	var item_id := Hotbar.get_selected_item_id()
	if item_id == &"":
		GameEvents.toast("Select a gift in the hotbar")
		return
	npc.receive_gift(item_id)

func _remove_focused_building() -> void:
	var focused := interaction_controller.get_focused()
	if focused == null:
		GameEvents.toast("Stand near a placed structure to pack it up")
		return
	var structure := focused.get_parent() as PlacedStructure
	if structure == null or structure.placement_id == &"" or structure.location_id == &"":
		GameEvents.toast("That cannot be packed up")
		return
	var data := structure.get_placeable_data()
	if BuildingState.remove_placement(structure.location_id, structure.placement_id, true):
		GameEvents.toastf("Packed up %s", [data.display_name if data != null else "structure"])
