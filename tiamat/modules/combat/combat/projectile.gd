class_name Projectile
extends Area2D

## A shot thrown in the world: a creature's from afar (`EnemyData.shot_speed`)
## or the player's from a bow (`RangedAttack`). It flies straight at its speed
## and is gone on the first hurtbox of a side hostile to its own it touches
## (`Hurtbox`), which it hurts unless that is still invincible, on a wall
## (`wall_mask`) or once it has flown its `reach`; it passes the hurtboxes of
## its own side. Aimed where its target stood, it is dodged by moving aside.
## It draws itself as a small glowing ball in its `color`. Its collision mask
## names the hurtboxes it touches: the games' layers 2 and 3 (the player's and
## the creatures').

## Its radius, drawn and touching.
const RADIUS := 3.5

## The hit it lands.
var damage: Damage
## Where it flies and how fast, in pixels a second.
var velocity := Vector2.ZERO
## How far it flies before it fades, in pixels.
var reach := 120.0
var color := Color(1.0, 0.62, 0.25)
## The layers of the world's walls, which stop it (the games' layer 1).
var wall_mask := 1
var _flown := 0.0
var _spent := false

func _init() -> void:
	collision_layer = 0
	collision_mask = 2 | 4
	monitorable = false
	z_index = 9
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)

## Throws a shot of `hit` from where `from` (the actor that throws it) stands
## toward `toward`, flying `speed` pixels a second for `distance` pixels, in
## `tint`, beside `from` in the world.
static func fire(from: Node2D, toward: Vector2, speed: float, distance: float, hit: Damage, tint: Color) -> Projectile:
	var shot := Projectile.new()
	shot.damage = hit
	shot.velocity = (toward - from.global_position).normalized() * speed
	shot.reach = distance
	shot.color = tint
	from.get_parent().add_child(shot)
	shot.global_position = from.global_position
	return shot

func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step := velocity * delta
	if wall_between(get_world_2d().direct_space_state, global_position, global_position + step, wall_mask):
		_end()
		return
	position += step
	_flown += step.length()
	if _flown >= reach or velocity.is_zero_approx():
		_end()

## Whether a wall lies on the way from `from` to `to` in `space`: a body on
## the layers `mask` names that is not an actor (a `CharacterBody2D`), whose
## hurtbox is what a shot hits. A ray, so a fast shot never passes through a
## thin wall.
static func wall_between(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, mask: int) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	var passed: Array[RID] = []
	for attempt in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		if not hit["collider"] is CharacterBody2D:
			return true
		passed.append(hit["rid"])
		query.exclude = passed
	return false

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + 1.5, Color(color, 0.35))
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_circle(Vector2.ZERO, RADIUS * 0.45, Color(1.0, 0.96, 0.85))

## Whether it has landed or faded, and hurts nothing more.
func is_spent() -> bool:
	return _spent

# A foe's hurtbox ends it, hurt or not (still invincible from the last hit).
func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if _spent or hurtbox == null or not hurtbox.enabled or not FactionData.are_hostile(damage.faction, hurtbox.faction):
		return
	_end()
	# What a hit sets off (a knockout, a scene change) waits until the physics
	# queries it came from are done.
	hurtbox.receive.call_deferred(damage)

func _end() -> void:
	_spent = true
	set_deferred(&"monitoring", false)
	queue_free()
