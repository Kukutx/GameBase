class_name DelverPlayer
extends TopDownPlayer

## The player of Ember Depths: walks, swings the weapon selected in the hotbar
## (its `MeleeAttack`) and uses what is near (its `InteractionController`), as
## a `TopDownPlayer`; picks another item of the hotbar (its `HotbarInput`) and
## drinks a potion.

@onready var facing_marker: Node2D = $Facing

func _ready() -> void:
	super()
	facing_changed.connect(_on_facing_changed)

func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return
	if event.is_action_pressed("drink_potion"):
		drink_potion()
		get_viewport().set_input_as_handled()

## Drinks the first item of the inventory that restores health. False when
## there is none or the player needs none.
func drink_potion() -> bool:
	for entry: Dictionary in InventoryState.get_entries():
		var item := ItemData.find(StringName(String(entry["id"])))
		if item != null and item.health_restore > 0:
			return InventoryState.consume(item)
	GameEvents.toast("No potion at hand")
	return false

func _on_facing_changed(direction: Vector2) -> void:
	# The marker is drawn pointing up.
	facing_marker.rotation = direction.angle() + PI / 2.0
