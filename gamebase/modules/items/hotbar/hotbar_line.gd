class_name HotbarLine
extends HudLine

## The hotbar on the HUD: each slot's item, how many the inventory holds of
## what is not a tool, and which slot is in hand (`HotbarService.get_text()`).

func _watch() -> void:
	watch(Hotbar.changed)
	watch(Hotbar.selected_slot_changed)
	watch(InventoryState.changed)

func _get_parts() -> PackedStringArray:
	return PackedStringArray([Hotbar.get_text()])
