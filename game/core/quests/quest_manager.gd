class_name QuestManager
extends Node

enum Status {
	INACTIVE,
	ACTIVE,
	COMPLETED,
}

signal quest_started(quest_id: StringName)
signal quest_progressed(quest_id: StringName, progress: int, required: int)
signal quest_completed(quest_id: StringName)

var _states: Dictionary = {}

func _ready() -> void:
	InventoryState.item_added.connect(_on_item_added)
	InventoryState.item_removed.connect(_on_inventory_item_removed)
	GameEvents.npc_talked.connect(_on_npc_talked)
	GameEvents.crop_harvested.connect(_on_crop_harvested)
	GameEvents.fish_caught.connect(_on_fish_caught)
	GameEvents.resource_mined.connect(_on_resource_mined)
	GameEvents.enemy_defeated.connect(_on_enemy_defeated)
	GameEvents.item_processed.connect(_on_item_processed)
	GameEvents.tool_upgraded.connect(_on_tool_upgraded)
	MineState.deepest_floor_changed.connect(_on_deepest_mine_floor_changed)

func get_quest(quest_id: StringName) -> QuestData:
	return ContentDB.get_quest(quest_id)

func start_quest(quest_id: StringName) -> bool:
	var quest := get_quest(quest_id)
	if quest == null:
		return false
	var state := get_state(quest_id)
	if int(state["status"]) != Status.INACTIVE:
		return false
	_states[String(quest_id)] = {"status": Status.ACTIVE, "progress": 0}
	quest_started.emit(quest_id)
	GameEvents.toastf("Quest started: %s", [quest.title])
	if quest.objective_type == QuestData.ObjectiveType.REACH_MINE_FLOOR:
		_sync_mine_floor_progress(quest)
	return true

func reset_new_game() -> void:
	_states.clear()
	for quest: QuestData in ContentDB.get_all_quests():
		if quest != null and quest.auto_start:
			start_quest(quest.id)

func get_state(quest_id: StringName) -> Dictionary:
	return (_states.get(String(quest_id), {"status": Status.INACTIVE, "progress": 0}) as Dictionary).duplicate(true)

func is_active(quest_id: StringName) -> bool:
	return int(get_state(quest_id)["status"]) == Status.ACTIVE

func is_completed(quest_id: StringName) -> bool:
	return int(get_state(quest_id)["status"]) == Status.COMPLETED

func get_active_summary() -> String:
	for key: String in _states.keys():
		var state: Dictionary = _states[key]
		if int(state.get("status", Status.INACTIVE)) != Status.ACTIVE:
			continue
		var quest := get_quest(StringName(key))
		if quest != null:
			return "%s  %d/%d" % [quest.title, int(state.get("progress", 0)), quest.required_amount]
	return "No active quest"

func get_journal_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var keys: Array[String] = []
	for key: String in _states.keys():
		keys.append(key)
	keys.sort()
	for key: String in keys:
		var quest := get_quest(StringName(key))
		var state: Dictionary = _states[key]
		var status := int(state.get("status", Status.INACTIVE))
		if quest == null or status == Status.INACTIVE:
			continue
		result.append({
			"id": key,
			"title": quest.title,
			"description": quest.description,
			"progress": int(state.get("progress", 0)),
			"required": quest.required_amount,
			"completed": status == Status.COMPLETED,
		})
	return result

func notify_npc_talk(npc_id: StringName) -> void:
	GameEvents.npc_talked.emit(npc_id)

func to_save_data() -> Dictionary:
	return _states.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	_states.clear()
	for raw_key: Variant in data.keys():
		var key := String(raw_key)
		var raw_state: Variant = data[raw_key]
		if not raw_state is Dictionary:
			continue
		var saved_state: Dictionary = raw_state
		var quest := get_quest(StringName(key))
		if quest == null:
			# Stable IDs should normally keep this resolvable, but preserve an orphan
			# state verbatim so restoring retired content can recover its history.
			_states[key] = saved_state.duplicate(true)
			continue
		var raw_status := _safe_int(saved_state.get("status", Status.INACTIVE), Status.INACTIVE)
		var progress := maxi(_safe_int(saved_state.get("progress", 0), 0), 0)
		var status := raw_status
		if not [Status.INACTIVE, Status.ACTIVE, Status.COMPLETED].has(status):
			status = Status.ACTIVE if progress > 0 else Status.INACTIVE
		match status:
			Status.INACTIVE:
				progress = 0
			Status.ACTIVE:
				progress = mini(progress, quest.required_amount)
			Status.COMPLETED:
				progress = quest.required_amount
		var normalized := {"status": status, "progress": progress}
		var raw_reward: Variant = saved_state.get("reward_snapshot", {})
		if raw_reward is Dictionary and not (raw_reward as Dictionary).is_empty():
			normalized["reward_snapshot"] = (raw_reward as Dictionary).duplicate(true)
		_states[key] = normalized
	_repair_completed_chains()

func reconcile_loaded_progress() -> void:
	# Called by SaveManager only after Inventory, Player, World and Mine state have
	# all been restored. This lets newly appended reach-floor quests synchronize
	# against historical depth without running reward transactions against stale
	# state from the previously active save.
	_retry_blocked_completions()
	var active_ids: Array[String] = []
	for key: String in _states.keys():
		if int((_states[key] as Dictionary).get("status", Status.INACTIVE)) == Status.ACTIVE:
			active_ids.append(key)
	for key: String in active_ids:
		var quest := get_quest(StringName(key))
		if quest != null and quest.objective_type == QuestData.ObjectiveType.REACH_MINE_FLOOR:
			_sync_mine_floor_progress(quest)

func _repair_completed_chains() -> void:
	var changed := true
	while changed:
		changed = false
		for quest: QuestData in ContentDB.get_all_quests():
			if quest == null or quest.next_quest_id == &"" or not is_completed(quest.id):
				continue
			var next_quest := get_quest(quest.next_quest_id)
			if next_quest == null:
				continue
			var next_state := get_state(next_quest.id)
			if int(next_state.get("status", Status.INACTIVE)) != Status.INACTIVE:
				continue
			_states[String(next_quest.id)] = {"status": Status.ACTIVE, "progress": 0}
			changed = true

func _on_item_added(item_id: StringName, quantity: int) -> void:
	_progress_matching(QuestData.ObjectiveType.COLLECT, item_id, quantity)

func _on_npc_talked(npc_id: StringName) -> void:
	_progress_matching(QuestData.ObjectiveType.TALK, npc_id, 1)

func _on_crop_harvested(crop_id: StringName, _item_id: StringName, quantity: int) -> void:
	_progress_matching(QuestData.ObjectiveType.HARVEST, crop_id, quantity)

func _on_fish_caught(fish_id: StringName, _item_id: StringName) -> void:
	_progress_matching(QuestData.ObjectiveType.FISH, fish_id, 1)

func _on_resource_mined(node_id: StringName, _item_id: StringName, quantity: int) -> void:
	_progress_matching(QuestData.ObjectiveType.MINE, node_id, quantity)

func _on_enemy_defeated(enemy_id: StringName, _combat_xp: int) -> void:
	_progress_matching(QuestData.ObjectiveType.DEFEAT, enemy_id, 1)

func _on_item_processed(recipe_id: StringName, _item_id: StringName, quantity: int) -> void:
	_progress_matching(QuestData.ObjectiveType.PROCESS, recipe_id, quantity)

func _on_tool_upgraded(upgrade_id: StringName, _result_item_id: StringName) -> void:
	_progress_matching(QuestData.ObjectiveType.UPGRADE, upgrade_id, 1)

func _on_deepest_mine_floor_changed(_deepest_floor: int) -> void:
	var active_ids: Array[String] = []
	for key: String in _states.keys():
		if int((_states[key] as Dictionary).get("status", Status.INACTIVE)) == Status.ACTIVE:
			active_ids.append(key)
	for key: String in active_ids:
		var quest := get_quest(StringName(key))
		if quest != null and quest.objective_type == QuestData.ObjectiveType.REACH_MINE_FLOOR:
			_sync_mine_floor_progress(quest)

func _sync_mine_floor_progress(quest: QuestData) -> void:
	if quest == null or quest.objective_type != QuestData.ObjectiveType.REACH_MINE_FLOOR or not is_active(quest.id):
		return
	var state := get_state(quest.id)
	var progress := mini(MineState.get_deepest_floor(), quest.required_amount)
	if progress <= int(state.get("progress", 0)):
		return
	state["progress"] = progress
	_states[String(quest.id)] = state
	quest_progressed.emit(quest.id, progress, quest.required_amount)
	if progress >= quest.required_amount:
		_complete(quest)

func _progress_matching(objective_type: QuestData.ObjectiveType, target_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var active_ids: Array[String] = []
	for key: String in _states.keys():
		var state: Dictionary = _states[key]
		if int(state.get("status", Status.INACTIVE)) == Status.ACTIVE:
			active_ids.append(key)
	for key: String in active_ids:
		var quest := get_quest(StringName(key))
		if quest == null or quest.objective_type != objective_type:
			continue
		if quest.target_id != &"" and quest.target_id != target_id:
			continue
		var state: Dictionary = _states[key]
		var progress := mini(int(state.get("progress", 0)) + amount, quest.required_amount)
		state["progress"] = progress
		_states[key] = state
		quest_progressed.emit(quest.id, progress, quest.required_amount)
		if progress >= quest.required_amount:
			_complete(quest)

func _complete(quest: QuestData) -> bool:
	var key := String(quest.id)
	var state: Dictionary = _states.get(key, {})
	if int(state.get("status", Status.INACTIVE)) != Status.ACTIVE:
		return false
	var reward := DeferredRewardSnapshot.ensure(state.get("reward_snapshot", {}), quest.reward_items, quest.reward_money)
	state["reward_snapshot"] = reward.duplicate(true)
	state["progress"] = quest.required_amount

	# Mark the quest complete before emitting inventory signals from the reward so
	# an inventory callback cannot re-enter this same completion transaction.
	state["status"] = Status.COMPLETED
	_states[key] = state
	if not DeferredRewardSnapshot.grant_items(reward):
		state["status"] = Status.ACTIVE
		_states[key] = state
		GameEvents.toast("Quest complete — make room for the promised reward")
		return false
	var reward_money := DeferredRewardSnapshot.get_money(reward)
	if reward_money > 0:
		PlayerState.add_money(reward_money)
	quest_completed.emit(quest.id)
	GameEvents.toastf("Quest complete: %s", [quest.title])
	if quest.next_quest_id != &"":
		start_quest(quest.next_quest_id)
	return true

func _on_inventory_item_removed(_item_id: StringName, _quantity: int) -> void:
	# Inventory removals often happen inside larger transactions (crafting,
	# upgrades, shipping). Retry blocked quest rewards on the next frame so a
	# reward cannot consume a slot halfway through another atomic operation.
	_retry_blocked_completions.call_deferred()

func _retry_blocked_completions() -> void:
	var blocked_ids: Array[String] = []
	for key: String in _states.keys():
		var state: Dictionary = _states[key]
		if int(state.get("status", Status.INACTIVE)) != Status.ACTIVE:
			continue
		var quest := get_quest(StringName(key))
		if quest != null and int(state.get("progress", 0)) >= quest.required_amount:
			blocked_ids.append(key)
	for key: String in blocked_ids:
		var quest := get_quest(StringName(key))
		if quest != null:
			_complete(quest)

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
