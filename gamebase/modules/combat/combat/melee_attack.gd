class_name MeleeAttack
extends Area2D

## The player's melee attack: on `action`, swings the weapon selected in the
## hotbar (a tool whose action is `TOOL_ACTION`) at every hurtbox in this area
## (`Hurtbox`) of a faction hostile to `faction`. It hits for the weapon's
## `tool_power` changed by the `attack_damage` stat, pushes what it hits away
## by `knockback`, costs `cost` of the game's attack vital (`CombatSettings.attack_vital_id`)
## changed by the `attack_cost` stat and
## swings again only after `cooldown_seconds`. A swing draws its arc
## (`SwingEffect`), is announced as `CombatEvents.attack_swung`, and a swing
## that lands shakes the screen a little (`GameCamera.shake_view()`). A child of the
## player, kept in front of it (`TopDownPlayer.reach_nodes`); its collision
## mask picks the hurtboxes it can reach.

## The tool action of weapons, which the combat module handles.
const TOOL_ACTION := &"attack"
const SWING_SCENE := preload("res://gamebase/modules/combat/combat/swing_effect.tscn")
const SHAKE_STRENGTH := 1.5
const SHAKE_SECONDS := 0.1

## The input action that swings the weapon.
@export var action: StringName = &"attack"
## How much of the attack vital (`CombatSettings.attack_vital_id`) a swing
## costs (0: none).
@export_range(0, 100, 1) var cost := 2
## The faction the swing belongs to.
@export var faction: StringName = FactionData.PLAYER
## Seconds before the next swing.
@export_range(0.0, 3.0, 0.05) var cooldown_seconds := 0.35
## How hard a swing pushes what it hits, in pixels a second.
@export_range(0.0, 600.0, 1.0) var knockback := 140.0

var _attack_busy := false
var _cooldown_left := 0.0
var _swings := NodePool.new(SWING_SCENE, 2)

func _ready() -> void:
	set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not InputLock.is_player_press(event, action):
		return
	if attack_selected_weapon():
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0:
		set_physics_process(false)

## Swings the weapon selected in the hotbar. False when no weapon is selected,
## the last swing is still cooling down or the swing could not be made.
func attack_selected_weapon() -> bool:
	if _attack_busy or is_cooling_down():
		return false
	var weapon := Hotbar.get_selected_item()
	if weapon == null or not weapon.is_tool() or weapon.tool_action != TOOL_ACTION:
		return false
	_attack_busy = true
	var result := _attack(weapon)
	_attack_busy = false
	return result

## Whether the last swing still keeps the next one back.
func is_cooling_down() -> bool:
	return _cooldown_left > 0.0

func get_attack_damage(weapon: ItemData) -> int:
	if weapon == null:
		return 0
	return maxi(roundi(GameStats.apply(&"attack_damage", weapon.tool_power)), 1)

## What a swing costs now, of the attack vital.
func get_cost() -> int:
	if cost <= 0:
		return 0
	return maxi(int(floor(float(cost) * GameStats.get_multiplier(&"attack_cost"))), 1)

func _attack(weapon: ItemData) -> bool:
	if not InventoryState.has_item(weapon.id, 1):
		GameEvents.toastf("You do not have %s", [weapon.display_name])
		return false
	if not Vitals.try_spend(CombatSettings.current().attack_vital_id, get_cost()):
		return false
	_cooldown_left = cooldown_seconds
	set_physics_process(_cooldown_left > 0.0)
	_play_attack_animation()
	_show_swing()
	CombatEvents.attack_swung.emit(weapon.id)
	var hits := 0
	for area: Area2D in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox != null and hurtbox.receive(Damage.new(get_attack_damage(weapon), faction, get_parent(), _push_toward(hurtbox))):
			hits += 1
	if hits > 0:
		GameCamera.shake_view(self, SHAKE_STRENGTH, SHAKE_SECONDS)
	return true

# The knockback of a hit on `hurtbox`: away from the swing's actor.
func _push_toward(hurtbox: Hurtbox) -> Vector2:
	var actor := get_parent() as Node2D
	var from := actor.global_position if actor != null else global_position
	var direction := (hurtbox.global_position - from).normalized()
	return (direction if not direction.is_zero_approx() else _swing_direction()) * knockback

# The way the swing goes: from the actor toward this area.
func _swing_direction() -> Vector2:
	return position.normalized() if not position.is_zero_approx() else Vector2.DOWN

func _show_swing() -> void:
	var swing := _swings.take(self) as SwingEffect
	swing.rotation = _swing_direction().angle()
	if not swing.finished.is_connected(_swings.give_back):
		swing.finished.connect(_swings.give_back)

func _play_attack_animation() -> void:
	var actor := get_parent()
	var visual := actor.get_node_or_null("ActorVisual") as DirectionalActorVisual if actor != null else null
	if visual != null:
		visual.play_action(&"attack")
