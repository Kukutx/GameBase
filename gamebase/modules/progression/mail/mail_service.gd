class_name MailService
extends Node

## The player's mailbox: it delivers each letter (`MailData`) once its condition
## holds, and keeps which letters arrived, which were read and whose reward
## (items and money) was claimed.
##
## Deliveries are checked when the day changes, a quest completes, a friendship
## or the world's state changes, and wait while a save loads or a new game is
## set up. A letter's reward is fixed when it arrives, and claiming it is
## refused while the items do not fit in the inventory. All of this lives in
## `WorldState` (`mail:<id>:...`), so it is saved with the world.
## `mail_received` announces each new letter.

signal mail_received(mail_id: StringName)
signal mail_read(mail_id: StringName)
signal mail_claimed(mail_id: StringName)

var _claiming: Dictionary = {}
# Whether the world changed since the last check, and whether a check is
# queued for before the next frame.
var _check_needed := false
var _check_scheduled := false

func _ready() -> void:
	WorldClock.day_changed.connect(_on_state_may_unlock_mail)
	QuestState.quest_completed.connect(_on_quest_completed)
	RelationshipState.friendship_changed.connect(_on_friendship_changed)
	WorldState.changed.connect(_on_world_state_changed)
	refresh_deliveries.call_deferred()

## Delivers every letter whose condition now holds. While the session changes
## (`GameSession.is_changing()`) the world is half restored or half set up, so
## the check waits for `GameSession.play_started`.
func refresh_deliveries() -> Array[StringName]:
	var delivered: Array[StringName] = []
	if GameSession.is_changing():
		return delivered
	_check_needed = false
	for mail: MailData in MailData.find_all():
		if mail == null:
			continue
		if WorldState.get_bool(_key(mail.id, "received")) or not mail.is_available():
			continue
		# Freeze delayed rewards before publishing receipt. If content changes before
		# the player opens this letter, claim still grants what was promised at delivery.
		_get_reward_snapshot(mail)
		WorldState.set_value(_key(mail.id, "received"), true)
		delivered.append(mail.id)
		mail_received.emit(mail.id)
		GameEvents.toastf("New mail: %s", [mail.subject])
	return delivered

func get_received_mail() -> Array[MailData]:
	refresh_deliveries()
	var result: Array[MailData] = []
	for mail: MailData in MailData.find_all():
		if mail != null and is_received(mail.id):
			result.append(mail)
	result.sort_custom(func(a: MailData, b: MailData) -> bool:
		var a_read := is_read(a.id)
		var b_read := is_read(b.id)
		if a_read != b_read:
			return not a_read
		return String(a.id) < String(b.id)
	)
	return result

func get_unread_mail() -> Array[MailData]:
	var result: Array[MailData] = []
	for mail: MailData in get_received_mail():
		if not is_read(mail.id):
			result.append(mail)
	return result

func has_unread() -> bool:
	return not get_unread_mail().is_empty()

func mark_read(mail_id: StringName) -> bool:
	if not is_received(mail_id):
		return false
	if not is_read(mail_id):
		WorldState.set_value(_key(mail_id, "read"), true)
		mail_read.emit(mail_id)
	return true

func claim_rewards(mail_id: StringName) -> bool:
	var claim_key := String(mail_id)
	if _claiming.has(claim_key):
		return false
	var mail := MailData.find(mail_id)
	if mail == null or not is_received(mail_id) or is_claimed(mail_id):
		return false
	_claiming[claim_key] = true
	var reward := _get_reward_snapshot(mail)
	if not DeferredRewardSnapshot.grant_items(reward):
		_claiming.erase(claim_key)
		GameEvents.toast("Make room in your inventory before claiming this letter")
		return false
	var reward_money := DeferredRewardSnapshot.get_money(reward)
	if reward_money > 0:
		PlayerState.add_money(reward_money)
	mark_read(mail_id)
	WorldState.set_value(_key(mail_id, "claimed"), true)
	mail_claimed.emit(mail_id)
	_claiming.erase(claim_key)
	return true

func is_received(mail_id: StringName) -> bool:
	if _check_needed:
		refresh_deliveries()
	return mail_id != &"" and WorldState.get_bool(_key(mail_id, "received"))

func is_read(mail_id: StringName) -> bool:
	return mail_id != &"" and WorldState.get_bool(_key(mail_id, "read"))

func is_claimed(mail_id: StringName) -> bool:
	return mail_id != &"" and WorldState.get_bool(_key(mail_id, "claimed"))

func _get_reward_snapshot(mail: MailData) -> Dictionary:
	if mail == null:
		return DeferredRewardSnapshot.capture({}, 0)
	var key := _key(mail.id, "reward_snapshot")
	var raw: Variant = WorldState.get_value(key, {})
	var reward := DeferredRewardSnapshot.ensure(raw, mail.reward_items, mail.reward_money)
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		WorldState.set_value(key, reward.duplicate(true))
	return reward

func _key(mail_id: StringName, suffix: String) -> StringName:
	return StringName("mail:%s:%s" % [String(mail_id), suffix])

func _on_state_may_unlock_mail(_day: int) -> void:
	refresh_deliveries()

func _on_quest_completed(_quest_id: StringName) -> void:
	refresh_deliveries()

func _on_friendship_changed(_npc_id: StringName, _points: int, _delta: int) -> void:
	refresh_deliveries()

# A letter's condition may read any of the world's state (a flag, a project).
# Writes come in bursts (a new day saves every field and machine), so they are
# checked once: before the next frame, or sooner when someone asks about the
# mail. The service's own keys change nothing it waits on, and a cleared or
# loaded world (an empty key) already holds which letters arrived in it.
func _on_world_state_changed(key: StringName, _value: Variant) -> void:
	if key == &"":
		_check_needed = false
		return
	if String(key).begins_with("mail:"):
		return
	_check_needed = true
	if not _check_scheduled:
		_check_scheduled = true
		_check_if_needed.call_deferred()

# A check while the session changes delivers nothing and leaves the world
# marked changed: `play_started` checks again, or the next write after a
# change that never reached play.
func _check_if_needed() -> void:
	_check_scheduled = false
	if _check_needed:
		refresh_deliveries()
