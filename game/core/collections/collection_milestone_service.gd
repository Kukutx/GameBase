class_name CollectionMilestoneService
extends Node

signal milestone_ready(milestone_id: StringName)
signal milestone_claimed(milestone_id: StringName)

const CLAIM_PREFIX := "collection:milestone:"
const NOTIFIED_PREFIX := "collection:milestone_ready:"
const QUALIFIED_PREFIX := "collection:milestone_qualified:"

var _claiming: Dictionary = {}

func _ready() -> void:
	CollectionState.collection_changed.connect(_on_collection_changed)
	_check_ready_milestones()

func get_milestone(id: StringName) -> CollectionMilestoneData:
	return ContentDB.get_collection_milestone(id)

func get_all_milestones() -> Array[CollectionMilestoneData]:
	return ContentDB.get_all_collection_milestones()

func get_progress(milestone: CollectionMilestoneData) -> int:
	if milestone == null:
		return 0
	if milestone.category != &"":
		return CollectionState.get_discovered_count(milestone.category)
	var completed := 0
	for prerequisite: StringName in milestone.prerequisites:
		if is_claimed(prerequisite):
			completed += 1
	return completed

func get_required(milestone: CollectionMilestoneData) -> int:
	return milestone.get_required_count() if milestone != null else 0

func is_ready(id: StringName) -> bool:
	var milestone := get_milestone(id)
	if milestone == null or is_claimed(id):
		return false
	# Once the player has qualified for a milestone, later content additions must
	# not revoke an already-promised reward by increasing the catalog size or
	# changing prerequisites. The old notified flag doubles as a legacy proof of
	# qualification for saves created before the dedicated flag existed.
	if WorldState.get_bool(_qualified_key(id)) or WorldState.get_bool(_notified_key(id)):
		return true
	if not _prerequisites_met(milestone):
		return false
	return get_progress(milestone) >= get_required(milestone)

func _prerequisites_met(milestone: CollectionMilestoneData) -> bool:
	if milestone == null:
		return false
	for prerequisite: StringName in milestone.prerequisites:
		if not is_claimed(prerequisite):
			return false
	return true

func is_claimed(id: StringName) -> bool:
	return WorldState.get_bool(_claim_key(id))

func claim(id: StringName) -> bool:
	var claim_key := String(id)
	if _claiming.has(claim_key):
		return false
	var milestone := get_milestone(id)
	if milestone == null or not is_ready(id):
		return false
	_claiming[claim_key] = true
	var reward := _get_reward_snapshot(milestone)
	if not DeferredRewardSnapshot.grant_items(reward):
		_claiming.erase(claim_key)
		GameEvents.toast("Inventory is full")
		return false
	var reward_money := DeferredRewardSnapshot.get_money(reward)
	if reward_money > 0:
		PlayerState.add_money(reward_money)
	for flag: StringName in milestone.unlock_flags:
		if flag != &"":
			WorldState.set_value(flag, true)
	WorldState.set_value(_claim_key(id), true)
	milestone_claimed.emit(id)
	_claiming.erase(claim_key)
	GameEvents.toastf("Archive reward: %s", [milestone.display_name])
	_check_ready_milestones()
	return true

func get_summary(milestone: CollectionMilestoneData) -> String:
	if milestone == null:
		return ""
	if is_claimed(milestone.id):
		return "%s — Claimed" % milestone.display_name
	var progress := get_progress(milestone)
	var required := get_required(milestone)
	var state := "Ready" if is_ready(milestone.id) else "%d/%d" % [progress, required]
	return "%s — %s" % [milestone.display_name, state]

func get_ready_count() -> int:
	var count := 0
	for milestone: CollectionMilestoneData in get_all_milestones():
		if is_ready(milestone.id):
			count += 1
	return count

func reconcile_loaded_state() -> void:
	# Claimed milestones are permanent achievements. Reapply the current unlock
	# flags so a later content update can safely add derived world flags without
	# requiring players to re-claim an already-consumed reward.
	for milestone: CollectionMilestoneData in get_all_milestones():
		if milestone == null or not is_claimed(milestone.id):
			continue
		for flag: StringName in milestone.unlock_flags:
			if flag != &"" and not WorldState.get_bool(flag):
				WorldState.set_value(flag, true)
	_check_ready_milestones()

func _on_collection_changed(_category: StringName, _item_id: StringName, _count: int) -> void:
	_check_ready_milestones()

func _check_ready_milestones() -> void:
	for milestone: CollectionMilestoneData in get_all_milestones():
		if milestone == null or not is_ready(milestone.id):
			continue
		if not WorldState.get_bool(_qualified_key(milestone.id)):
			WorldState.set_value(_qualified_key(milestone.id), true)
		# Freeze the promised reward as soon as the milestone first becomes ready.
		# Older saves without a snapshot are backfilled from current content here.
		_get_reward_snapshot(milestone)
		var notify_key := _notified_key(milestone.id)
		if WorldState.get_bool(notify_key):
			continue
		WorldState.set_value(notify_key, true)
		milestone_ready.emit(milestone.id)
		GameEvents.toastf("Archive milestone ready: %s", [milestone.display_name])

func _get_reward_snapshot(milestone: CollectionMilestoneData) -> Dictionary:
	if milestone == null:
		return DeferredRewardSnapshot.capture({}, 0)
	var key := _reward_key(milestone.id)
	var raw: Variant = WorldState.get_value(key, {})
	var reward := DeferredRewardSnapshot.ensure(raw, milestone.reward_items, milestone.reward_money)
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		WorldState.set_value(key, reward.duplicate(true))
	return reward

func _claim_key(id: StringName) -> StringName:
	return StringName(CLAIM_PREFIX + String(id) + ":claimed")

func _notified_key(id: StringName) -> StringName:
	return StringName(NOTIFIED_PREFIX + String(id))

func _qualified_key(id: StringName) -> StringName:
	return StringName(QUALIFIED_PREFIX + String(id))

func _reward_key(id: StringName) -> StringName:
	return StringName(CLAIM_PREFIX + String(id) + ":reward_snapshot")
