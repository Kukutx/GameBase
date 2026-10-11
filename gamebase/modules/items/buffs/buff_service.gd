class_name BuffService
extends Node

signal buff_applied(buff_id: StringName, expires_at: int)
signal buff_expired(buff_id: StringName)
signal buffs_changed

var _active: Dictionary = {}

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_minute_changed)

func apply_buff(buff_id: StringName) -> bool:
	var data := FoodBuffData.find(buff_id)
	if data == null:
		return false
	var expires_at := get_absolute_minute() + data.duration_minutes
	_active[String(buff_id)] = expires_at
	buff_applied.emit(buff_id, expires_at)
	buffs_changed.emit()
	GameEvents.toastf("Buff: %s (%d min)", [data.display_name, data.duration_minutes])
	return true

func has_buff(buff_id: StringName) -> bool:
	_prune_expired()
	return _active.has(String(buff_id))

func get_minutes_remaining(buff_id: StringName) -> int:
	_prune_expired()
	return maxi(int(_active.get(String(buff_id), 0)) - get_absolute_minute(), 0)

## `GameStats` source: the product of the active buffs' multipliers of `stat`.
func get_stat_multiplier(stat: StringName) -> float:
	_prune_expired()
	var result := 1.0
	for raw_id: Variant in _active.keys():
		var data := FoodBuffData.find(StringName(String(raw_id)))
		if data != null:
			result *= data.multipliers.get(stat, 1.0)
	return result

## `GameStats` source: the sum of the active buffs' bonuses to `stat`.
func get_stat_bonus(stat: StringName) -> float:
	_prune_expired()
	var result := 0.0
	for raw_id: Variant in _active.keys():
		var data := FoodBuffData.find(StringName(String(raw_id)))
		if data != null:
			result += data.bonuses.get(stat, 0.0)
	return result

func get_active_entries() -> Array[Dictionary]:
	_prune_expired()
	var result: Array[Dictionary] = []
	for raw_id: Variant in _active.keys():
		var buff_id := StringName(String(raw_id))
		var data := FoodBuffData.find(buff_id)
		if data == null:
			continue
		result.append({
			"id": String(buff_id),
			"display_name": data.display_name,
			"minutes_remaining": get_minutes_remaining(buff_id),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["display_name"]) < String(b["display_name"]))
	return result

func get_summary() -> String:
	var entries := get_active_entries()
	if entries.is_empty():
		return ""
	var parts := PackedStringArray()
	for entry: Dictionary in entries:
		parts.append(tr("%s %dm") % [tr(String(entry["display_name"])), entry["minutes_remaining"]])
	return " · ".join(parts)

func clear() -> void:
	if _active.is_empty():
		return
	_active.clear()
	buffs_changed.emit()

func to_save_data() -> Dictionary:
	_prune_expired()
	return _active.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	_active.clear()
	for raw_id: Variant in data.keys():
		var buff_id := StringName(String(raw_id))
		if FoodBuffData.find(buff_id) == null:
			continue
		var now := get_absolute_minute()
		var raw_expiry: Variant = data[raw_id]
		var expires_at := 0
		if typeof(raw_expiry) == TYPE_INT or typeof(raw_expiry) == TYPE_FLOAT:
			expires_at = clampi(int(raw_expiry), 0, now + GameClock.MINUTES_PER_DAY)
		if expires_at > now:
			_active[String(buff_id)] = expires_at
	buffs_changed.emit()

func get_absolute_minute(day: int = -1, minute_of_day: int = -1) -> int:
	var resolved_day := WorldClock.day if day < 1 else day
	var resolved_minute := WorldClock.minute_of_day if minute_of_day < 0 else minute_of_day
	return (maxi(resolved_day, 1) - 1) * GameClock.MINUTES_PER_DAY + clampi(resolved_minute, 0, GameClock.MINUTES_PER_DAY - 1)

func _on_minute_changed(_day: int, _minute_of_day: int) -> void:
	_prune_expired()

func _prune_expired() -> void:
	var now := get_absolute_minute()
	var expired: Array[String] = []
	for key: String in _active.keys():
		if int(_active[key]) <= now:
			expired.append(key)
	if expired.is_empty():
		return
	for key: String in expired:
		_active.erase(key)
		buff_expired.emit(StringName(key))
	buffs_changed.emit()
