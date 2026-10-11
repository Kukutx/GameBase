class_name MeleeController
extends Area2D

## The tool action of Farm1's weapons.
const TOOL_ACTION := &"attack"

@export var action: StringName = &"use_tool"
@export_range(0, 100, 1) var energy_cost := 2

var _attack_busy := false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(action):
		return
	if attack_selected_weapon():
		get_viewport().set_input_as_handled()

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

func _attack(weapon: ItemData) -> bool:
	if not InventoryState.has_item(weapon.id, 1):
		GameEvents.toastf("You do not have %s", [weapon.display_name])
		return false
	var energy_multiplier := GameStats.get_multiplier(&"tool_energy") * GameStats.get_multiplier(&"attack_energy")
	var adjusted_cost := maxi(int(floor(float(energy_cost) * energy_multiplier)), 1)
	if not PlayerState.consume_energy(adjusted_cost):
		GameEvents.toast("Not enough energy")
		return false
	_play_attack_animation()
	var hits := 0
	for body: Node2D in get_overlapping_bodies():
		if not body.has_method("take_damage"):
			continue
		body.call("take_damage", get_attack_damage(weapon))
		hits += 1
	if hits == 0:
		GameEvents.toastf("Swung %s", [weapon.display_name])
	return true

func get_attack_damage(weapon: ItemData) -> int:
	if weapon == null:
		return 0
	return maxi(roundi(GameStats.apply(&"attack_damage", weapon.tool_power)), 1)

func _play_attack_animation() -> void:
	var actor := get_parent()
	if actor == null:
		return
	var visual := actor.get_node_or_null("ActorVisual") as DirectionalActorVisual
	if visual != null:
		visual.play_action(&"attack")
