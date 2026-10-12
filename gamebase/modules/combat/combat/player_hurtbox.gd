class_name PlayerHurtbox
extends Hurtbox

## The player's hurtbox (`Hurtbox`), of the player's faction: a hit takes the
## player's health (`PlayerState`), staggers the player while its knockback
## carries them (`TopDownPlayer.stagger()`), shakes the screen (`ScreenShake`)
## and is announced as `CombatEvents.player_hurt`. A player without health
## left takes no more hits. A child of the player.

const SHAKE_STRENGTH := 3.0
const SHAKE_SECONDS := 0.2

func _init() -> void:
	faction = FactionData.PLAYER
	invincible_seconds = 0.6

func _ready() -> void:
	super()
	hurt.connect(_on_hurt)

func can_be_hurt_by(damage: Damage) -> bool:
	return PlayerState.health > 0 and super(damage)

func _on_hurt(damage: Damage) -> void:
	var player := get_parent() as TopDownPlayer
	if player != null:
		player.stagger(get_knockback_left())
	var before := PlayerState.health
	if not PlayerState.take_damage(damage.amount):
		return
	CombatEvents.player_hurt.emit(before - PlayerState.health)
	ScreenShake.shake(self, SHAKE_STRENGTH, SHAKE_SECONDS)
