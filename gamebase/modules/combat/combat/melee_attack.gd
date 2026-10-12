class_name MeleeAttack
extends Area2D

## The player's melee attack: on `action`, swings the weapon selected in the
## hotbar (a tool whose action is `TOOL_ACTION`) at every body in this area
## that takes damage (`take_damage(amount)`, as `HostileCreature` does). It
## hits for the weapon's `tool_power` changed by the `attack_damage` stat and
## costs `energy_cost` changed by the `attack_energy` stat. A child of the
## player, placed in front of it; its collision mask picks what it can hit.

## The tool action of weapons, which the combat module handles.
const TOOL_ACTION := &"attack"

## The input action that swings the weapon.
@export var action: StringName = &"attack"
## Energy a swing costs (0: none).
@export_range(0, 100, 1) var energy_cost := 2

var _attack_busy := false

func _unhandled_input(event: InputEvent) -> void:
	if not InputLock.is_player_press(event, action):
		return
	if attack_selected_weapon():
		get_viewport().set_input_as_handled()

## Swings the weapon selected in the hotbar. False when no weapon is selected
## or the swing could not be made.
func attack_selected_weapon() -> bool:
	if _attack_busy:
		return false
	var weapon := Hotbar.get_selected_item()
	if weapon == null or not weapon.is_tool() or weapon.tool_action != TOOL_ACTION:
		return false
	_attack_busy = true
	var result := _attack(weapon)
	_attack_busy = false
	return result

func get_attack_damage(weapon: ItemData) -> int:
	if weapon == null:
		return 0
	return maxi(roundi(GameStats.apply(&"attack_damage", weapon.tool_power)), 1)

## The energy a swing costs now.
func get_energy_cost() -> int:
	if energy_cost <= 0:
		return 0
	return maxi(int(floor(float(energy_cost) * GameStats.get_multiplier(&"attack_energy"))), 1)

func _attack(weapon: ItemData) -> bool:
	if not InventoryState.has_item(weapon.id, 1):
		GameEvents.toastf("You do not have %s", [weapon.display_name])
		return false
	if not PlayerState.consume_energy(get_energy_cost()):
		GameEvents.toast("Not enough energy")
		return false
	_play_attack_animation()
	var hits := 0
	for body: Node2D in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.call("take_damage", get_attack_damage(weapon))
			hits += 1
	if hits == 0:
		GameEvents.toastf("Swung %s", [weapon.display_name])
	return true

func _play_attack_animation() -> void:
	var actor := get_parent()
	var visual := actor.get_node_or_null("ActorVisual") as DirectionalActorVisual if actor != null else null
	if visual != null:
		visual.play_action(&"attack")
