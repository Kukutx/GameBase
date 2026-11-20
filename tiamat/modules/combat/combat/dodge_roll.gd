class_name DodgeRoll
extends Node

## The player's dodge: on `action`, a child of a `TopDownPlayer` rolls it
## `distance` pixels in `seconds` the way the player moves, or faces when
## standing (`TopDownPlayer.dash()`), and no hit hurts it on the way (the
## player's hurtbox, `Hurtbox.make_invincible()`); the player shows faded while
## it rolls. It rolls again only after `cooldown_seconds`, never while the
## controls are held or a hit staggers the player, and costs `cost` of the
## game's attack vital (`CombatSettings.attack_vital_id`; none, and rolls are
## free). A boon, a perk or an upgrade shortens or lengthens that wait through
## the `COOLDOWN_STAT` stat. Each roll is announced as
## `CombatEvents.player_dodged`.

## The stat the wait between rolls is changed by (`GameStats`): 0.5 halves it.
const COOLDOWN_STAT := &"dodge_cooldown"

## The input action that rolls.
@export var action: StringName = &"dodge"
## How far a roll carries the player, in pixels.
@export_range(8.0, 200.0, 1.0) var distance := 56.0
## How long a roll takes, all of it safe from hits.
@export_range(0.05, 1.0, 0.01) var seconds := 0.2
## Seconds after a roll before the next.
@export_range(0.0, 5.0, 0.05) var cooldown_seconds := 0.6
## How much of the attack vital a roll costs (0: none).
@export_range(0, 100, 1) var cost := 0
## How faded the player shows while it rolls.
@export_range(0.0, 1.0, 0.05) var roll_alpha := 0.45

var _cooldown_left := 0.0
var _fade: Tween

func _ready() -> void:
	set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not InputLock.is_player_press(event, action):
		return
	if roll():
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0:
		set_physics_process(false)

## Rolls the player. False while the last roll still keeps this one back, the
## player cannot act or reels from a hit, or the attack vital falls short.
func roll() -> bool:
	var player := get_parent() as TopDownPlayer
	if player == null or is_cooling_down() or player.is_input_locked() or player.is_staggered() or player.is_dashing():
		return false
	if not Vitals.try_spend(CombatSettings.current().attack_vital_id, cost):
		return false
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if direction.length_squared() < 0.01:
		direction = player.facing
	player.dash(direction.normalized() * distance / seconds, seconds)
	var hurtbox := Hurtbox.of(player)
	if hurtbox != null:
		hurtbox.make_invincible(seconds)
	_cooldown_left = seconds + get_cooldown()
	set_physics_process(true)
	_fade_while_rolling(player)
	CombatEvents.player_dodged.emit()
	return true

## Whether the last roll still keeps the next one back.
func is_cooling_down() -> bool:
	return _cooldown_left > 0.0

## The wait after a roll before the next: `cooldown_seconds` changed by the
## `COOLDOWN_STAT` stat, never below none.
func get_cooldown() -> float:
	return maxf(GameStats.apply(COOLDOWN_STAT, cooldown_seconds), 0.0)

func _fade_while_rolling(player: CanvasItem) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	player.modulate.a = roll_alpha
	_fade = create_tween()
	_fade.tween_property(player, "modulate:a", 1.0, seconds).set_ease(Tween.EASE_IN)
