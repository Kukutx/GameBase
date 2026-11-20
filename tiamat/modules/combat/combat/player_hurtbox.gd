class_name PlayerHurtbox
extends Hurtbox

## The player's hurtbox (`Hurtbox`), of the player's faction: a hit takes the
## player's health (`CombatSettings.health_vital_id`), staggers the player
## while its knockback carries them (`TopDownPlayer.stagger()`), plays `hurt`
## on the player's `TopDownPlayer.actor_visual` (`death` when it took the last
## of it), shakes the screen (`GameCamera.shake_view()`) and is announced as
## `CombatEvents.player_hurt`. A player without health left, or passing out,
## takes no more hits. A child of the player.
##
## The player chooses how hard hits land on them in the settings
## (`DAMAGE_TAKEN_OPTION`, which the combat module declares), read at each
## hit: a light choice halves a hit, a heavy one adds half again.

const SHAKE_STRENGTH := 3.0
const SHAKE_SECONDS := 0.2
## The player's option of how hard hits land (`GameOption`): one of the
## choices of `DAMAGE_TAKEN_SCALES`. A game that replaces the option with
## choices of its own takes a hit whole on a choice not named here.
const DAMAGE_TAKEN_OPTION := &"damage_taken"
const DAMAGE_TAKEN_SCALES: Dictionary[String, float] = {"Light": 0.5, "Standard": 1.0, "Heavy": 1.5}

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

## The health a hit of `amount` takes from the player at their choice of
## damage taken (`DAMAGE_TAKEN_OPTION`), rounded, and at least 1 of a hit
## that does any.
static func damage_taken(amount: int) -> int:
	if amount <= 0 or GameSettings.options.find(DAMAGE_TAKEN_OPTION) == null:
		return amount
	var choice := str(GameSettings.get_option(DAMAGE_TAKEN_OPTION))
	return maxi(1, roundi(amount * DAMAGE_TAKEN_SCALES.get(choice, 1.0)))

func _on_hurt(damage: Damage) -> void:
	var player := get_parent() as TopDownPlayer
	if player != null:
		player.stagger(get_knockback_left())
	var health := CombatSettings.current().health_vital_id
	var taken := Vitals.drain(health, damage_taken(damage.amount))
	if taken <= 0:
		return
	if player != null and player.actor_visual != null:
		player.actor_visual.play_action(&"death" if Vitals.get_value(health) <= 0 else &"hurt")
	CombatEvents.player_hurt.emit(taken)
	GameCamera.shake_view(self, SHAKE_STRENGTH, SHAKE_SECONDS)
