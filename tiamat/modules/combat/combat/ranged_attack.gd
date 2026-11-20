class_name RangedAttack
extends Node

## The player's shot: on `action`, shoots the weapon selected in the hotbar
## when it is a bow (a tool whose action is `TOOL_ACTION`), as a `Projectile`
## the way the player faces, or at the nearest foe within
## `aim_assist_degrees` of that way and in reach, with no wall between (`aim()`).
## The shot hurts the first foe it meets for the bow's power changed by the
## `attack_damage` stat (`WeaponUse`, which `MeleeAttack` shares), lays the
## affliction the bow's tags call for (`WeaponUse.affliction_of()`) and
## pushes it away by `knockback`; it costs `cost` of the game's attack vital changed by
## the `attack_cost` stat, plays the player's attack, is announced as
## `CombatEvents.attack_swung` and lets the next one go only after
## `cooldown_seconds`. A child of the player (a `TopDownPlayer`), beside the
## `MeleeAttack` that swings the other weapons on the same control.

## The tool action of bows, which the combat module handles.
const TOOL_ACTION := &"ranged_attack"
## How many hurtboxes in reach aiming looks among, at most.
const MAX_AIMED := 32

## The input action that shoots.
@export var action: StringName = &"attack"
## How much of the attack vital (`CombatSettings.attack_vital_id`) a shot
## costs (0: none).
@export_range(0, 100, 1) var cost := 2
## The faction the shot belongs to.
@export var faction: StringName = FactionData.PLAYER
## Seconds before the next shot.
@export_range(0.0, 3.0, 0.05) var cooldown_seconds := 0.45
## How fast a shot flies, in pixels a second.
@export_range(40.0, 900.0, 5.0) var shot_speed := 280.0
## How far a shot flies, in pixels, and how far away a foe is aimed at.
@export_range(16.0, 600.0, 1.0) var distance := 160.0
## How hard a shot pushes what it hits, in pixels a second.
@export_range(0.0, 600.0, 1.0) var knockback := 90.0
## How far off the way the player faces a foe may stand and still be aimed
## at, in degrees (0: a shot flies only the way the player faces).
@export_range(0.0, 90.0, 1.0) var aim_assist_degrees := 25.0
@export var shot_color := Color(0.96, 0.9, 0.72)
## The layers of the hurtboxes aimed at (the games' layer 3, the creatures').
@export_flags_2d_physics var aim_mask := 4
## The layers of the walls a foe behind is not aimed at, which also stop a
## shot (the games' layer 1).
@export_flags_2d_physics var wall_mask := 1

var _busy := false
var _cooldown_left := 0.0

func _ready() -> void:
	set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not InputLock.is_player_press(event, action):
		return
	if shoot_selected_weapon():
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0:
		set_physics_process(false)

## Shoots the bow selected in the hotbar. False when no bow is selected, the
## last shot still keeps the next back or the player cannot pay for it.
func shoot_selected_weapon() -> bool:
	var actor := get_parent() as Node2D
	var bow := WeaponUse.selected(TOOL_ACTION)
	if actor == null or bow == null or _busy or is_cooling_down():
		return false
	_busy = true
	var paid := WeaponUse.pay(bow, cost)
	_busy = false
	if not paid:
		return false
	_cooldown_left = cooldown_seconds
	set_physics_process(_cooldown_left > 0.0)
	var way := aim()
	WeaponUse.play_attack(actor)
	var hit := Damage.new(WeaponUse.damage_of(bow), faction, actor, way * knockback)
	var affliction := WeaponUse.affliction_of(bow)
	hit.affliction_id = affliction.id if affliction != null else &""
	var shot := Projectile.fire(actor, actor.global_position + way, shot_speed, distance, hit, shot_color)
	shot.wall_mask = wall_mask
	CombatEvents.attack_swung.emit(bow.id)
	return true

## Whether the last shot still keeps the next one back.
func is_cooling_down() -> bool:
	return _cooldown_left > 0.0

## What a shot costs now, of the attack vital.
func get_cost() -> int:
	return WeaponUse.cost_of(cost)

## The way a shot would fly now, a unit vector: at the nearest foe's hurtbox
## within `aim_assist_degrees` of the way the player faces and within
## `distance`, with no wall between, else the way the player faces.
func aim() -> Vector2:
	var actor := get_parent() as Node2D
	var player := actor as TopDownPlayer
	var facing := player.facing if player != null else Vector2.DOWN
	if actor == null or aim_assist_degrees <= 0.0 or not actor.is_inside_tree():
		return facing
	var space := actor.get_world_2d().direct_space_state
	var from := actor.global_position
	var way := facing
	var nearest := INF
	for hurtbox: Hurtbox in _foes_in_reach(space, from):
		var to := hurtbox.global_position - from
		if to.is_zero_approx() or to.length() >= nearest or absf(rad_to_deg(facing.angle_to(to))) > aim_assist_degrees:
			continue
		if not Projectile.wall_between(space, from, hurtbox.global_position, wall_mask):
			nearest = to.length()
			way = to.normalized()
	return way

# The hurtboxes of the sides hostile to the shot's within `distance` of `from`.
func _foes_in_reach(space: PhysicsDirectSpaceState2D, from: Vector2) -> Array[Hurtbox]:
	var circle := CircleShape2D.new()
	circle.radius = distance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, from)
	query.collision_mask = aim_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var foes: Array[Hurtbox] = []
	for hit: Dictionary in space.intersect_shape(query, MAX_AIMED):
		var hurtbox := hit["collider"] as Hurtbox
		if hurtbox != null and hurtbox.enabled and FactionData.are_hostile(faction, hurtbox.faction):
			foes.append(hurtbox)
	return foes
