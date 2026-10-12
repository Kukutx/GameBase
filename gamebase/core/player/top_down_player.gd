class_name TopDownPlayer
extends CharacterBody2D

## A player seen from above, which a game's player extends. It walks with the
## core's move controls at `move_speed`, times the `MOVE_SPEED_STAT` stat
## (`GameStats`). It keeps the nodes it reaches with (`reach_nodes`, such as
## its `InteractionController`) `reach` in front of where it faces. It stands
## still while anything holds the controls (`InputLock`) or its
## `actor_visual` plays an action, and that visual plays `hurt` or `death`
## when the player loses health. A game adds its own actions in
## `_unhandled_input`, checking `is_input_locked()` first, and an `_ready()`
## of its own calls `super()`.

## Emitted when the player turns to face another way, not while it keeps
## walking the way it faces.
signal facing_changed(facing: Vector2)

## The stat that speeds the player up or slows them down.
const MOVE_SPEED_STAT := &"move_speed"

@export var move_speed := 110.0
## How far in front of the player its `reach_nodes` sit.
@export var reach := 16.0
## The nodes kept `reach` in front of the player: what it interacts, works or
## attacks with.
@export var reach_nodes: Array[NodePath] = []
## The player's animated look, if it has one.
@export var actor_visual: DirectionalActorVisual

## The way the player faces, a unit vector.
var facing := Vector2.DOWN

var _previous_health := 0
var _stagger_left := 0.0

func _ready() -> void:
	_previous_health = PlayerState.health
	PlayerState.health_changed.connect(_on_health_changed)

func _physics_process(delta: float) -> void:
	if _stagger_left > 0.0:
		_stagger_left = maxf(_stagger_left - delta, 0.0)
		velocity = Vector2.ZERO
		return
	if is_input_locked():
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * move_speed * GameStats.get_multiplier(MOVE_SPEED_STAT)
	move_and_slide()
	if direction.length_squared() > 0.01:
		face(direction)

## Stops the player walking for `seconds`, while a hit's knockback carries
## them (combat's `PlayerHurtbox`). A longer stagger under way stays.
func stagger(seconds: float) -> void:
	_stagger_left = maxf(_stagger_left, seconds)

## Whether the player is staggered (`stagger()`) and does not walk.
func is_staggered() -> bool:
	return _stagger_left > 0.0

## Turns the player to face `direction`, and its reach with it.
func face(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	var turned := not direction.normalized().is_equal_approx(facing)
	facing = direction.normalized()
	for path: NodePath in reach_nodes:
		var node := get_node_or_null(path) as Node2D
		if node != null:
			node.position = facing * reach
	if turned:
		facing_changed.emit(facing)

## Whether the player cannot act: something holds the controls (a menu, a
## dialogue, a minigame) or the player's own action is still playing.
func is_input_locked() -> bool:
	return InputLock.is_locked() or (actor_visual != null and actor_visual.is_action_playing())

func _on_health_changed(current: int, _maximum: int) -> void:
	if current < _previous_health and actor_visual != null:
		actor_visual.play_action(&"death" if current <= 0 else &"hurt")
	_previous_health = current
