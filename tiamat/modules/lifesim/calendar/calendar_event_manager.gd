class_name CalendarEventManager
extends Node

## Which calendar events (`CalendarEventData`, such as a fair or a market) are
## on at the world clock's day and minute, and the yearly reward for taking part
## in one. It checks every event again each minute and announces each start and
## end (`event_started`, `event_ended`).
##
## Which events are on is not saved: it is worked out again from the clock once
## a save loads. A participation reward (items, money, skill experience) can be
## claimed once per event in each in-game year, while the event is on; it is
## refused while the items do not fit in the inventory, and the claim is kept in
## `WorldState`.

signal event_started(calendar_event_id: StringName)
signal event_ended(calendar_event_id: StringName)
signal active_events_changed
signal participation_claimed(calendar_event_id: StringName, year: int)

var _active: Dictionary = {}
var _claiming: Dictionary = {}

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_time_changed)
	WorldClock.day_changed.connect(_on_day_changed)
	refresh(WorldClock.day, WorldClock.minute_of_day)

func refresh(day: int, minute_of_day: int) -> void:
	var next_active: Dictionary = {}
	for event: CalendarEventData in CalendarEventData.find_all():
		if event.is_active(day, minute_of_day):
			next_active[String(event.id)] = event
	for key: String in _active.keys():
		if not next_active.has(key):
			event_ended.emit(StringName(key))
	for key: String in next_active.keys():
		if not _active.has(key):
			event_started.emit(StringName(key))
	var changed := not _same_keys(_active, next_active)
	_active = next_active
	if changed:
		active_events_changed.emit()

func is_active(event_id: StringName) -> bool:
	return _active.has(String(event_id))

func get_active_events(location_id: StringName = &"") -> Array[CalendarEventData]:
	var result: Array[CalendarEventData] = []
	for value: Variant in _active.values():
		var event := value as CalendarEventData
		if event == null:
			continue
		if location_id == &"" or event.location_id == &"" or event.location_id == location_id:
			result.append(event)
	result.sort_custom(func(a: CalendarEventData, b: CalendarEventData) -> bool: return a.start_minute < b.start_minute)
	return result

func get_summary(location_id: StringName = &"") -> String:
	var events := get_active_events(location_id)
	if events.is_empty():
		return ""
	var names := PackedStringArray()
	for event: CalendarEventData in events:
		names.append(tr(event.display_name))
	return ", ".join(names)

func get_event(event_id: StringName) -> CalendarEventData:
	return CalendarEventData.find(event_id)

func get_year(day: int = -1) -> int:
	var resolved_day := WorldClock.day if day < 1 else day
	return GameCalendar.current().get_year(resolved_day)

func has_claimed_participation(event_id: StringName, year: int = -1) -> bool:
	var resolved_year := get_year() if year < 1 else year
	return event_id != &"" and WorldState.get_bool(_participation_key(event_id, resolved_year))

func can_claim_participation(event_id: StringName) -> bool:
	var event := get_event(event_id)
	if event == null or not event.has_participation_reward():
		return false
	if not is_active(event_id) or not event.is_active(WorldClock.day, WorldClock.minute_of_day):
		return false
	return not has_claimed_participation(event_id)

func claim_participation(event_id: StringName) -> bool:
	var claim_key := String(event_id)
	if _claiming.has(claim_key):
		return false
	var event := get_event(event_id)
	if event == null or not can_claim_participation(event_id):
		return false
	# Bind this transaction to the year in which participation began. Reward
	# signals can synchronously advance the clock; they must not move the claim
	# marker into a different year's event.
	var claim_year := get_year()
	_claiming[claim_key] = true
	if not InventoryState.apply_transaction_atomic({}, event.reward_items):
		_claiming.erase(claim_key)
		GameEvents.toast("Inventory is full")
		return false
	if event.reward_money > 0:
		Wallet.add(event.reward_money)
	if event.reward_skill != &"" and event.reward_skill_xp > 0:
		Skills.add_xp(event.reward_skill, event.reward_skill_xp)
	WorldState.set_value(_participation_key(event_id, claim_year), true)
	participation_claimed.emit(event_id, claim_year)
	_claiming.erase(claim_key)
	GameEvents.toastf("Joined %s", [event.display_name])
	return true

func get_participation_summary(event_id: StringName) -> String:
	var event := get_event(event_id)
	if event == null:
		return ""
	if not event.has_participation_reward():
		return event.display_name
	if has_claimed_participation(event_id):
		return "%s · joined this year" % event.display_name
	if can_claim_participation(event_id):
		return "%s · reward ready" % event.display_name
	return event.display_name

func _participation_key(event_id: StringName, year: int) -> StringName:
	return StringName("event:%s:year:%d:participated" % [String(event_id), maxi(year, 1)])

func _on_time_changed(day: int, minute_of_day: int) -> void:
	refresh(day, minute_of_day)

func _on_day_changed(day: int) -> void:
	refresh(day, WorldClock.minute_of_day)

func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a.keys():
		if not b.has(key):
			return false
	return true
