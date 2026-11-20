class_name DelverPlayer
extends TopDownPlayer

## The player of Ember Depths: walks, swings the weapon selected in the hotbar
## (its `MeleeAttack`) and uses what is near (its `InteractionController`), as
## a `TopDownPlayer`; picks another item of the hotbar (its `HotbarInput`) and
## drinks a potion: an antidote while poisoned, else one that heals.

@onready var facing_marker: Node2D = $Facing

func _ready() -> void:
	facing_changed.connect(_on_facing_changed)

func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return
	if event.is_action_pressed("drink_potion"):
		drink_potion()
		get_viewport().set_input_as_handled()

## Drinks the first item of the inventory that lifts an affliction on the
## player (`PlayerHurtbox.would_cure()`, an antidote while poisoned), else the
## first that restores health. False when there is none or the player needs
## none.
func drink_potion() -> bool:
	var healing: ItemData = null
	for entry: Dictionary in InventoryState.get_entries():
		var item := ItemData.find(StringName(String(entry["id"])))
		if item == null:
			continue
		if PlayerHurtbox.would_cure(item):
			return InventoryState.consume(item)
		if healing == null and item.restores.get(CombatSettings.current().health_vital_id, 0) > 0:
			healing = item
	if healing != null:
		return InventoryState.consume(healing)
	GameEvents.toast("No potion at hand")
	return false

func _on_facing_changed(direction: Vector2) -> void:
	# The marker is drawn pointing up.
	facing_marker.rotation = direction.angle() + PI / 2.0
