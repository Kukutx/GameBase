class_name HotbarInput
extends Node

## Picks the hotbar's slot from the player's input, as a child of the player:
## the number keys pick a slot, `next_action` and `previous_action` step
## through the slots, and so does the mouse wheel. A number key the player
## bound to a control is that control's, never a slot's. It does nothing while
## the player cannot act (`TopDownPlayer.is_input_locked()`, or `InputLock` for
## another parent).

## The action that selects the next slot; none when empty.
@export var next_action := &"hotbar_next"
## The action that selects the previous slot; none when empty.
@export var previous_action := &"hotbar_prev"
@export var number_keys := true
@export var mouse_wheel := true

func _unhandled_input(event: InputEvent) -> void:
	if _is_locked():
		return
	var step := _step_for(event)
	if step != 0:
		Hotbar.cycle_slot(step)
	else:
		var slot := _slot_for(event)
		if slot < 0:
			return
		Hotbar.select_slot(slot)
	get_viewport().set_input_as_handled()

func _is_locked() -> bool:
	var player := get_parent() as TopDownPlayer
	return player.is_input_locked() if player != null else InputLock.is_locked()

# The slot a number key picks, or -1.
func _slot_for(event: InputEvent) -> int:
	var key := event as InputEventKey
	if not number_keys or key == null or not key.pressed or key.echo:
		return -1
	var slot := int(key.physical_keycode) - int(KEY_1)
	if slot < 0 or slot >= mini(HotbarService.SLOT_COUNT, 9) or _is_bound(event):
		return -1
	return slot

# Whether an action of the game (not one of the engine's `ui_` actions) takes
# `event`: a control the player bound to that key.
static func _is_bound(event: InputEvent) -> bool:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_") and InputMap.event_is_action(event, action, true):
			return true
	return false

# How many slots on the event steps: 1, -1 or 0.
func _step_for(event: InputEvent) -> int:
	if _pressed(event, next_action):
		return 1
	if _pressed(event, previous_action):
		return -1
	var button := event as InputEventMouseButton
	if mouse_wheel and button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -1
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return 1
	return 0

func _pressed(event: InputEvent, action: StringName) -> bool:
	return action != &"" and InputMap.has_action(action) and event.is_action_pressed(action)
