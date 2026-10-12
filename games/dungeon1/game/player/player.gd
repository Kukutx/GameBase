class_name DelverPlayer
extends CharacterBody2D

## The player of Ember Depths: walks, swings the weapon selected in the hotbar
## (its `MeleeAttack`), drinks a potion, picks another item of the hotbar and
## uses what is near (its `InteractionController`).

@export var move_speed := 110.0
## How far in front of the player its attack and its reach for things sit.
@export var reach := 16.0

@onready var interaction_controller: InteractionController = $InteractionController
@onready var melee_attack: MeleeAttack = $MeleeAttack
@onready var facing_marker: Node2D = $Facing

func _physics_process(_delta: float) -> void:
	if InputLock.is_locked():
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()
	if direction.length_squared() > 0.01:
		var facing := direction.normalized()
		interaction_controller.position = facing * reach
		melee_attack.position = facing * reach
		facing_marker.rotation = facing.angle() + PI / 2.0

func _unhandled_input(event: InputEvent) -> void:
	if InputLock.is_locked():
		return
	if event.is_action_pressed("drink_potion"):
		drink_potion()
	elif event.is_action_pressed("next_item"):
		Hotbar.cycle_slot(1)
	elif event is InputEventKey and event.pressed and not event.echo and _slot_for_key((event as InputEventKey).physical_keycode) >= 0:
		Hotbar.select_slot(_slot_for_key((event as InputEventKey).physical_keycode))
	else:
		return
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

func _slot_for_key(keycode: Key) -> int:
	var slot := int(keycode) - int(KEY_1)
	return slot if slot >= 0 and slot < HotbarService.SLOT_COUNT else -1
