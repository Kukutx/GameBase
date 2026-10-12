class_name Hurtbox
extends Area2D

## Where an actor is hit in real time: a child of the actor (the player, a
## creature) that hits reach through `receive()`, from a melee swing that
## overlaps it (`MeleeAttack`) or a creature that strikes its actor. Damage of
## a faction hostile to the hurtbox's (`FactionData.are_hostile()`) hurts: the
## hurtbox announces it (`hurt`) for the actor to lose the health, flashes the
## actor, pushes it back by the hit's knockback when it is a
## `CharacterBody2D`, and no other hit hurts for `invincible_seconds`.

signal hurt(damage: Damage)

## How long the actor flashes after a hit.
const FLASH_SECONDS := 0.12
## How bright the actor flashes.
const FLASH_COLOR := Color(2.4, 2.4, 2.4)
## How long a hit's knockback pushes, fading out.
const KNOCKBACK_SECONDS := 0.16

## The actor's faction.
@export var faction: StringName
## Seconds after a hit during which no other hit hurts.
@export_range(0.0, 5.0, 0.05) var invincible_seconds := 0.3
## How far a hit's knockback pushes the actor: 0 for not at all.
@export_range(0.0, 4.0, 0.05) var knockback_scale := 1.0
## Whether hits reach it at all (a defeated creature's reach nothing). Turning
## it off also stops a knockback under way.
@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_knockback_left = 0.0

var _invincible_left := 0.0
var _knockback := Vector2.ZERO
var _knockback_left := 0.0
var _flash: Tween
var _rest_modulate := Color.WHITE

func _ready() -> void:
	# It runs only while a hit plays out.
	set_physics_process(false)

## The hurtbox among `actor`'s children, or null.
static func of(actor: Node) -> Hurtbox:
	if actor == null:
		return null
	for child: Node in actor.get_children():
		if child is Hurtbox:
			return child
	return null

## Takes `damage`: false when it does not hurt (see `can_be_hurt_by()`).
func receive(damage: Damage) -> bool:
	if not can_be_hurt_by(damage):
		return false
	_invincible_left = invincible_seconds
	_knockback = damage.knockback * knockback_scale
	_knockback_left = 0.0 if _knockback.is_zero_approx() else KNOCKBACK_SECONDS
	set_physics_process(_invincible_left > 0.0 or _knockback_left > 0.0)
	_flash_actor()
	hurt.emit(damage)
	return true

## Whether `damage` would hurt: the hurtbox is on and not invincible, and the
## damage is some and comes from a hostile faction.
func can_be_hurt_by(damage: Damage) -> bool:
	return enabled and damage != null and damage.amount > 0 and not is_invincible() and FactionData.are_hostile(damage.faction, faction)

## Whether no hit hurts now, after the last one.
func is_invincible() -> bool:
	return _invincible_left > 0.0

## Seconds the last hit's knockback still pushes the actor.
func get_knockback_left() -> float:
	return _knockback_left

func _physics_process(delta: float) -> void:
	_invincible_left = maxf(_invincible_left - delta, 0.0)
	if _knockback_left > 0.0:
		var push := _knockback * (_knockback_left / KNOCKBACK_SECONDS)
		_knockback_left = maxf(_knockback_left - delta, 0.0)
		var body := get_parent() as CharacterBody2D
		if body != null:
			body.move_and_collide(push * delta)
	if _invincible_left <= 0.0 and _knockback_left <= 0.0:
		set_physics_process(false)

func _flash_actor() -> void:
	var actor := get_parent() as CanvasItem
	if actor == null:
		return
	if _flash != null and _flash.is_valid():
		_flash.kill()
	else:
		_rest_modulate = actor.modulate
	actor.modulate = FLASH_COLOR
	_flash = create_tween()
	_flash.tween_property(actor, "modulate", _rest_modulate, FLASH_SECONDS)
