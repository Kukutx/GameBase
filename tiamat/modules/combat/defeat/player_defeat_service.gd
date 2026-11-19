class_name PlayerDefeatService
extends Node

## Defeats the player when their health (`CombatSettings.health_vital_id`) runs
## out: they pass out (`GameSession.pass_out()`, cause
## `GameSession.CAUSE_DEFEAT`), lose `CombatSettings.defeat_money_loss_percent`
## of their money and wake at home the next morning with every vital full. The
## defeat is announced as `CombatEvents.player_defeated`. Health that runs out
## while the player already passes out for another cause, or that a save holds
## at 0, defeats them once that is over or once play starts.

func _ready() -> void:
	Vitals.depleted.connect(_on_vital_depleted)
	GameSession.passed_out.connect(func(_cause: StringName, _woke_at_home: bool) -> void: _check_health())
	GameSession.play_started.connect(_check_health)

func _on_vital_depleted(vital_id: StringName) -> void:
	if vital_id == CombatSettings.current().health_vital_id:
		_check_health()

func _check_health() -> void:
	var health := CombatSettings.current().health_vital_id
	if Vitals.has_vital(health) and Vitals.get_value(health) <= 0 and not GameSession.is_passing_out():
		_defeat.call_deferred()

func _defeat() -> void:
	var health := CombatSettings.current().health_vital_id
	# Healed in the same frame, or already out for another cause.
	if GameSession.is_passing_out() or not Vitals.has_vital(health) or Vitals.get_value(health) > 0:
		return
	var loss := [0]
	var woke_at_home := await GameSession.pass_out(GameSession.CAUSE_DEFEAT, _recover.bind(loss))
	var lost: int = loss[0]
	CombatEvents.player_defeated.emit(lost)
	if woke_at_home:
		GameEvents.toastf("You were defeated and lost %dg", [lost]) if lost > 0 else GameEvents.toast("You were defeated and woke up at home")
	else:
		GameEvents.toastf("You were defeated, lost %dg, and recovered where you fell", [lost]) if lost > 0 else GameEvents.toast("You were defeated and recovered where you fell")

# Takes the defeat's share of the money (into `loss[0]`) and fills every vital.
func _recover(loss: Array) -> void:
	var percent := CombatSettings.current().defeat_money_loss_percent
	if percent > 0 and Wallet.money > 0:
		loss[0] = Wallet.lose(maxi(ceili(Wallet.money * percent / 100.0), 1))
	for vital: VitalData in VitalData.find_all():
		Vitals.refill(vital.id)
