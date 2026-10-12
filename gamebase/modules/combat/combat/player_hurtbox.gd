class_name PlayerHurtbox
extends Hurtbox

## The player's hurtbox (`Hurtbox`), of the player's faction: a hit takes the
## player's health (`CombatSettings.health_vital_id`), staggers the player
## while its knockback carries them (`TopDownPlayer.stagger()`), plays `hurt`
## on the player's `TopDownPlayer.actor_visual` (`death` when it took the last
## of it), shakes the screen (`ScreenShake`) and is announced as
## `CombatEvents.player_hurt`. A player without health left, or passing out,
## takes no more hits. A child of the player.

const SHAKE_STRENGTH := 3.0
const SHAKE_SECONDS := 0.2

func _init() -> void:
	faction = FactionData.PLAYER
	invincible_seconds = 0.6

func _ready() -> void:
	super()
	hurt.connect(_on_hurt)

func can_be_hurt_by(damage: Damage) -> bool:
	return is_standing() and not GameSession.is_passing_out() and super(damage)

## Whether the player still stands: they have health left, or the game gives
## them none to lose (`CombatSettings.health_vital_id`).
static func is_standing() -> bool:
	var health := CombatSettings.current().health_vital_id
	return not Vitals.has_vital(health) or Vitals.get_value(health) > 0

func _on_hurt(damage: Damage) -> void:
	var player := get_parent() as TopDownPlayer
	if player != null:
		player.stagger(get_knockback_left())
	var health := CombatSettings.current().health_vital_id
	var taken := Vitals.drain(health, damage.amount)
	if taken <= 0:
		return
	if player != null and player.actor_visual != null:
		player.actor_visual.play_action(&"death" if Vitals.get_value(health) <= 0 else &"hurt")
	CombatEvents.player_hurt.emit(taken)
	ScreenShake.shake(self, SHAKE_STRENGTH, SHAKE_SECONDS)
