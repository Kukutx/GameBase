class_name QuestManager
extends Node

## The player's quests (`QuestData`): which have started, how far each
## objective has come and which are done. An objective moves on by itself as
## its event fires (`QuestObjective`): a crop harvested, a talk with an NPC, a
## mine floor reached, whatever module announces it. It listens only to the
## events of the active quests' objectives, and not while a save is restored
## or a new game resets the services (`GameSession.is_changing()`), which is
## not play. A quest pays its reward (items and money) once every objective
## is met.
##
## A quest whose reward items do not fit stays active and completes once the
## inventory has room; a completed quest starts the next one of its chain
## (`next_quest_id`). Quests are saved with the game, and a new game starts the
## quests marked `auto_start`. `quest_started`, `quest_progressed` and
## `quest_completed` announce each step.

enum Status {
	INACTIVE,
	ACTIVE,
	COMPLETED,
}

signal quest_started(quest_id: StringName)
## An objective of an active quest moved on: `objective` is its index.
signal quest_progressed(quest_id: StringName, objective: int, progress: int, required: int)
signal quest_completed(quest_id: StringName)

# quest id -> {"status": Status, "progress": Array[int] per objective,
# "reward_snapshot": the reward promised when it could not be given yet}
var _states: Dictionary = {}
# event -> the GameEventListener on it
var _listeners: Dictionary = {}

func _ready() -> void:
	InventoryState.item_removed.connect(_on_inventory_item_removed)

func _exit_tree() -> void:
	for listener: GameEventListener in _listeners.values():
		listener.stop()
	_listeners.clear()

func get_quest(quest_id: StringName) -> QuestData:
	return QuestData.find(quest_id)

func start_quest(quest_id: StringName) -> bool:
	var quest := get_quest(quest_id)
	if quest == null:
		return false
	if int(get_state(quest_id)["status"]) != Status.INACTIVE:
		return false
	_states[String(quest_id)] = {"status": Status.ACTIVE, "progress": _no_progress(quest)}
	quest_started.emit(quest_id)
	GameEvents.toastf("Quest started: %s", [quest.title])
	_listen()
	for index: int in quest.objectives.size():
		if quest.objectives[index] != null and quest.objectives[index].measure != &"":
			_set_progress(quest, index, quest.objectives[index].read_measure())
	_complete_if_met(quest)
	return true

func reset_new_game() -> void:
	_states.clear()
	for quest: QuestData in QuestData.find_all():
		if quest != null and quest.auto_start:
			start_quest(quest.id)
	_listen()

## The quest's state: its status and the progress of each objective, a copy.
func get_state(quest_id: StringName) -> Dictionary:
	var quest := get_quest(quest_id)
	var empty := {"status": Status.INACTIVE, "progress": _no_progress(quest) if quest != null else []}
	return (_states.get(String(quest_id), empty) as Dictionary).duplicate(true)

## How far objective `objective` of the quest has come.
func get_progress(quest_id: StringName, objective := 0) -> int:
	var progress: Array = get_state(quest_id)["progress"]
	return int(progress[objective]) if objective >= 0 and objective < progress.size() else 0

func is_active(quest_id: StringName) -> bool:
	return int(get_state(quest_id)["status"]) == Status.ACTIVE

func is_completed(quest_id: StringName) -> bool:
	return int(get_state(quest_id)["status"]) == Status.COMPLETED

## The first active quest and its first objective still open, as the HUD
## shows it ("Gather Berries  2/3").
func get_active_summary() -> String:
	for key: String in _sorted_keys():
		var quest := get_quest(StringName(key))
		if quest == null or not is_active(quest.id):
			continue
		var progress: Array = (_states[key] as Dictionary)["progress"]
		for index: int in quest.objectives.size():
			var required := quest.objectives[index].required_amount
			if int(progress[index]) < required or index == quest.objectives.size() - 1:
				return "%s  %d/%d" % [tr(quest.title), int(progress[index]), required]
	return tr("No active quest")

## The started quests, sorted by id: {"id", "title", "description",
## "completed", "objectives": [{"description", "progress", "required"}]}.
func get_journal_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in _sorted_keys():
		var quest := get_quest(StringName(key))
		var state: Dictionary = _states[key]
		var status := int(state["status"])
		if quest == null or status == Status.INACTIVE:
			continue
		var objectives: Array[Dictionary] = []
		for index: int in quest.objectives.size():
			objectives.append({
				"description": quest.objectives[index].description,
				"progress": int((state["progress"] as Array)[index]),
				"required": quest.objectives[index].required_amount,
			})
		result.append({
			"id": key,
			"title": quest.title,
			"description": quest.description,
			"completed": status == Status.COMPLETED,
			"objectives": objectives,
		})
	return result

func to_save_data() -> Dictionary:
	return _states.duplicate(true)

## Loads quest states. States of quests that are not content, or with an
## unknown status, are dropped; an objective's progress is a count up to what
## it requires, one per objective of the quest as it is.
func load_save_data(data: Dictionary) -> void:
	_states.clear()
	for raw_key: Variant in data.keys():
		var key := String(raw_key)
		var raw_state: Variant = data[raw_key]
		var quest := get_quest(StringName(key))
		if quest == null or not raw_state is Dictionary:
			continue
		var saved_state: Dictionary = raw_state
		var status := SaveValues.whole_number_or(saved_state.get("status", -1), -1)
		if not status in [Status.INACTIVE, Status.ACTIVE, Status.COMPLETED]:
			continue
		var saved_progress: Variant = saved_state.get("progress", [])
		var progress := _no_progress(quest)
		for index: int in progress.size():
			var required := quest.objectives[index].required_amount
			match status:
				Status.ACTIVE:
					var saved: Variant = (saved_progress as Array)[index] if saved_progress is Array and index < (saved_progress as Array).size() else 0
					progress[index] = mini(SaveValues.count(saved), required)
				Status.COMPLETED:
					progress[index] = required
		var normalized := {"status": status, "progress": progress}
		var raw_reward: Variant = saved_state.get("reward_snapshot", {})
		if raw_reward is Dictionary and not (raw_reward as Dictionary).is_empty():
			normalized["reward_snapshot"] = (raw_reward as Dictionary).duplicate(true)
		_states[key] = normalized
	_listen()

## Completes the active quests whose objectives are met but whose reward did
## not fit the inventory yet.
func complete_ready_quests() -> void:
	for key: String in _sorted_keys():
		var quest := get_quest(StringName(key))
		if quest != null and is_active(quest.id):
			_complete_if_met(quest)

# Listens to the events the active quests' objectives count, and to no other.
func _listen() -> void:
	var events: Dictionary = {}
	for key: String in _states:
		var quest := get_quest(StringName(key))
		if quest != null and int((_states[key] as Dictionary)["status"]) == Status.ACTIVE:
			for objective: QuestObjective in quest.objectives:
				if objective != null:
					events[objective.event] = true
	for event: StringName in _listeners.keys():
		if not events.has(event):
			(_listeners[event] as GameEventListener).stop()
			_listeners.erase(event)
	for event: StringName in events:
		if not _listeners.has(event):
			var listener := GameEventListener.new(event, func(args: Dictionary) -> void: _on_event(event, args))
			if listener.start():
				_listeners[event] = listener

func _on_event(event: StringName, args: Dictionary) -> void:
	if GameSession.is_changing():
		return
	for key: String in _sorted_keys():
		var quest := get_quest(StringName(key))
		if quest == null or not is_active(quest.id):
			continue
		var moved := false
		for index: int in quest.objectives.size():
			var objective := quest.objectives[index]
			if objective == null or objective.event != event:
				continue
			var counted := objective.count(args)
			if counted <= 0:
				continue
			moved = true
			if objective.measure != &"":
				_set_progress(quest, index, objective.read_measure())
			else:
				_set_progress(quest, index, get_progress(quest.id, index) + counted)
		# Only the quest this event moved on: a met quest whose reward waits for
		# room retries when the inventory gives an item up.
		if moved:
			_complete_if_met(quest)

# Moves objective `index` of the active quest on to `progress` (up to what it
# requires); never back.
func _set_progress(quest: QuestData, index: int, progress: int) -> void:
	var state: Dictionary = _states[String(quest.id)]
	var progresses: Array = state["progress"]
	var required := quest.objectives[index].required_amount
	var value := mini(progress, required)
	if value <= int(progresses[index]):
		return
	progresses[index] = value
	quest_progressed.emit(quest.id, index, value, required)

func _complete_if_met(quest: QuestData) -> void:
	var progress: Array = (_states[String(quest.id)] as Dictionary)["progress"]
	for index: int in quest.objectives.size():
		if int(progress[index]) < quest.objectives[index].required_amount:
			return
	_complete(quest)

func _complete(quest: QuestData) -> bool:
	var key := String(quest.id)
	var state: Dictionary = _states.get(key, {})
	if int(state.get("status", Status.INACTIVE)) != Status.ACTIVE:
		return false
	var reward := DeferredRewardSnapshot.ensure(state.get("reward_snapshot", {}), quest.reward_items, quest.reward_money)
	state["reward_snapshot"] = reward.duplicate(true)

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
	_listen()
	quest_completed.emit(quest.id)
	GameEvents.toastf("Quest complete: %s", [quest.title])
	if quest.next_quest_id != &"":
		start_quest(quest.next_quest_id)
	return true

# Retries blocked rewards when the inventory gives up an item. Removals often
# happen inside larger transactions (crafting, upgrades, shipping), so the
# retry runs on the next frame, never halfway through another one.
func _on_inventory_item_removed(_item_id: StringName, _quantity: int) -> void:
	complete_ready_quests.call_deferred()

func _no_progress(quest: QuestData) -> Array[int]:
	var progress: Array[int] = []
	progress.resize(quest.objectives.size())
	progress.fill(0)
	return progress

func _sorted_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_states.keys())
	keys.sort()
	return keys
