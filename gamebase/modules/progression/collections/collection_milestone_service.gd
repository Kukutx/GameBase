class_name CollectionMilestoneService
extends Node

## The collection milestones (`CollectionMilestoneData`): rewards for discovering
## a number of a category's items in `CollectionState`, or for claiming a set of
## other milestones. It tells the player when one is ready and pays its reward
## (items and money) when they claim it.
##
## A milestone needs the milestones it requires claimed first. Once ready it
## stays ready, and its reward is fixed at that moment, even if the content
## changes later; claiming is refused while the items do not fit in the
## inventory. What is ready and claimed lives in `WorldState`
## (`collection:milestone...`), so it is saved with the world. `milestone_ready`
## and `milestone_claimed` announce each step.

signal milestone_ready(milestone_id: StringName)
signal milestone_claimed(milestone_id: StringName)

const CLAIM_PREFIX := "collection:milestone:"
const NOTIFIED_PREFIX := "collection:milestone_ready:"
const QUALIFIED_PREFIX := "collection:milestone_qualified:"

var _claiming: Dictionary = {}

func _ready() -> void:
	# Progress counts discovered items, so only a discovery can make a
	# milestone ready.
	CollectionState.item_discovered.connect(_on_item_discovered)
	_check_ready_milestones()

func get_milestone(id: StringName) -> CollectionMilestoneData:
	return CollectionMilestoneData.find(id)

func get_all_milestones() -> Array[CollectionMilestoneData]:
	return CollectionMilestoneData.find_all()

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
	# changing prerequisites.
	if WorldState.get_bool(_qualified_key(id)):
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
		return tr("%s — Claimed") % tr(milestone.display_name)
	var progress := get_progress(milestone)
	var required := get_required(milestone)
	if is_ready(milestone.id):
		return tr("%s — Ready") % tr(milestone.display_name)
	return "%s — %d/%d" % [tr(milestone.display_name), progress, required]

func get_ready_count() -> int:
	var count := 0
	for milestone: CollectionMilestoneData in get_all_milestones():
		if is_ready(milestone.id):
			count += 1
	return count

func _on_item_discovered(_category: StringName, _item_id: StringName) -> void:
	_check_ready_milestones()

func _check_ready_milestones() -> void:
	for milestone: CollectionMilestoneData in get_all_milestones():
		if milestone == null or not is_ready(milestone.id):
			continue
		if not WorldState.get_bool(_qualified_key(milestone.id)):
			WorldState.set_value(_qualified_key(milestone.id), true)
		# Freeze the promised reward as soon as the milestone first becomes ready.
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
