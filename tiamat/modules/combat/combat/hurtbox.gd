class_name Hurtbox
extends Area2D

## Where an actor is hit in real time: a child of the actor (the player, a
## creature) that hits reach through `receive()`, from a melee swing that
## overlaps it (`MeleeAttack`) or a creature that strikes its actor. Damage of
## a faction hostile to the hurtbox's (`FactionData.are_hostile()`) hurts: the
## hurtbox announces it (`hurt`) for the actor to lose the health, flashes the
## actor, pushes it back by the hit's knockback when it is a
## `CharacterBody2D`, and no other hit hurts for `invincible_seconds`. A hit
## that brings an affliction (`Damage.affliction_id`, an `AfflictionData`)
## lays it on the hurtbox (`afflict()`) unless it is immune to it
## (`immune_to`), which then takes health on its own ticks (`ailed`) until it
## wears off or the hurtbox turns off, and may slow its actor while it lasts
## (`get_speed_scale()`, `slowed`).

signal hurt(damage: Damage)
## An affliction on it took health (`afflict()`): with no push and no stun,
## even in the moments after a hit when nothing else hurts.
signal ailed(damage: Damage)
## An affliction took hold of it, not laid on it already (`afflict()`).
signal afflicted(affliction: AfflictionData)
## How fast its actor goes changed (`get_speed_scale()`): an affliction that
## slows took hold or lifted.
signal slowed(speed_scale: float)

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
## The afflictions that never take hold of it, by id (an ember creature's
## burning).
@export var immune_to: Array[StringName] = []
## Whether hits reach it at all (a defeated creature's reach nothing). Turning
## it off also stops a knockback under way.
@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_knockback_left = 0.0
			cure()

var _invincible_left := 0.0
var _knockback := Vector2.ZERO
var _knockback_left := 0.0
var _flash: Tween
var _rest_modulate := Color.WHITE
var _afflictions := Afflictions.new()
var _speed_scale := 1.0

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
	if damage.affliction_id != &"":
		afflict(AfflictionData.find(damage.affliction_id), damage.faction)
	return true

## Whether `damage` would hurt: the hurtbox is on and not invincible, and the
## damage is some and comes from a hostile faction.
func can_be_hurt_by(damage: Damage) -> bool:
	return enabled and damage != null and damage.amount > 0 and not is_invincible() and FactionData.are_hostile(damage.faction, faction)

## Whether no hit hurts now, after the last one.
func is_invincible() -> bool:
	return _invincible_left > 0.0

## Lays `affliction` on it, from a hit of `from_faction`, in real time
## (`Afflictions.lay()`): it takes health on its ticks (`ailed`), and laid
## again lasts as long again from now, so hits faster than its ticks keep it
## burning. False when nothing is laid: on a hurtbox that is off, cannot ail
## (`can_ail()`) or is immune to it (`immune_to`).
func afflict(affliction: AfflictionData, from_faction: StringName = &"") -> bool:
	if affliction == null or not enabled or not can_ail() or immune_to.has(affliction.id):
		return false
	set_physics_process(true)
	if _afflictions.lay(affliction, from_faction):
		afflicted.emit(affliction)
		_check_speed()
	return true

## The afflictions on it now, in the order laid.
func get_afflictions() -> Array[AfflictionData]:
	return _afflictions.get_all()

## Whether the affliction `affliction_id` is on it now.
func is_afflicted(affliction_id: StringName) -> bool:
	return _afflictions.has(affliction_id)

## Lifts every affliction from it.
func cure() -> void:
	_afflictions.clear()
	_check_speed()

## How fast its actor goes now, as a share of its speed: slower while an
## affliction that slows is on it (`AfflictionData.speed_scale`), 1.0
## otherwise.
func get_speed_scale() -> float:
	return _speed_scale

## Whether an affliction may take its health now: while it is on.
func can_ail() -> bool:
	return enabled

## Lets no hit hurt for `seconds` from now (a dodge, `DodgeRoll`), or for
## longer while the last hit's moment lasts longer.
func make_invincible(seconds: float) -> void:
	_invincible_left = maxf(_invincible_left, seconds)
	set_physics_process(_invincible_left > 0.0 or _knockback_left > 0.0)

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
	_afflictions.advance(delta, _on_tick)
	_check_speed()
	if _invincible_left <= 0.0 and _knockback_left <= 0.0 and _afflictions.is_empty():
		set_physics_process(false)

# An affliction's tick takes health, flashing the actor in its colour, while
# it may (a tick may have defeated the actor and cured it of the rest).
func _on_tick(affliction: AfflictionData, tick: Damage) -> void:
	if can_ail():
		_flash_actor(affliction.color)
		ailed.emit(tick)

func _check_speed() -> void:
	var speed_scale := _afflictions.get_speed_scale()
	if speed_scale != _speed_scale:
		_speed_scale = speed_scale
		slowed.emit(speed_scale)

func _flash_actor(color := FLASH_COLOR) -> void:
	var actor := get_parent() as CanvasItem
	if actor == null:
		return
	if _flash != null and _flash.is_valid():
		_flash.kill()
	else:
		_rest_modulate = actor.modulate
	actor.modulate = color
	_flash = create_tween()
	_flash.tween_property(actor, "modulate", _rest_modulate, FLASH_SECONDS)
