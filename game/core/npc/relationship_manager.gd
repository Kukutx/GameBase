class_name RelationshipManager
extends Node

signal friendship_changed(npc_id: StringName, points: int, delta: int)

const POINTS_PER_HEART := 250
const MAX_HEARTS := 10

var _points: Dictionary = {}
var _last_talk_day: Dictionary = {}
var _last_gift_day: Dictionary = {}

func get_points(npc_id: StringName) -> int:
	return int(_points.get(String(npc_id), 0))

func get_hearts(npc_id: StringName) -> int:
	return clampi(get_points(npc_id) / POINTS_PER_HEART, 0, MAX_HEARTS)

func get_heart_progress(npc_id: StringName) -> float:
	return clampf(float(get_points(npc_id)) / float(POINTS_PER_HEART * MAX_HEARTS), 0.0, 1.0)

func add_friendship(npc_id: StringName, delta: int) -> int:
	if npc_id == &"" or delta == 0:
		return get_points(npc_id)
	var key := String(npc_id)
	var next := clampi(get_points(npc_id) + delta, 0, POINTS_PER_HEART * MAX_HEARTS)
	var applied := next - get_points(npc_id)
	_points[key] = next
	if applied != 0:
		friendship_changed.emit(npc_id, next, applied)
	return next

func record_talk(npc_id: StringName) -> bool:
	if npc_id == &"":
		return false
	var key := String(npc_id)
	if int(_last_talk_day.get(key, 0)) == WorldClock.day:
		return false
	_last_talk_day[key] = WorldClock.day
	add_friendship(npc_id, 10)
	return true

func give_gift(profile: NpcProfileData, item_id: StringName) -> int:
	if profile == null or profile.id == &"":
		return 0
	var key := String(profile.id)
	if int(_last_gift_day.get(key, 0)) == WorldClock.day:
		GameEvents.toastf("You already gave %s a gift today", [profile.display_name])
		return 0
	var item := ItemCatalog.get_item(item_id)
	if item == null or item.kind == ItemData.Kind.TOOL or item.kind == ItemData.Kind.SEED:
		GameEvents.toast("That is not a suitable gift")
		return 0
	# Reserve today's gift before touching inventory. item_removed listeners can
	# synchronously re-enter give_gift(); without this guard the same NPC could
	# receive multiple gifts before _last_gift_day was committed.
	var previous_gift_day: Variant = _last_gift_day.get(key, null)
	_last_gift_day[key] = WorldClock.day
	if not InventoryState.remove_item(item_id, 1):
		if previous_gift_day == null:
			_last_gift_day.erase(key)
		else:
			_last_gift_day[key] = previous_gift_day
		GameEvents.toast("You do not have that item")
		return 0
	var delta := profile.friendship_for_gift(item)
	var birthday := profile.is_birthday()
	if birthday:
		delta *= 2
	if delta > 0:
		delta = roundi(float(delta) * Skills.get_friendship_multiplier())
	add_friendship(profile.id, delta)
	GameEvents.gift_given.emit(profile.id, item_id, delta)
	var occasion := " · Birthday!" if birthday else ""
	GameEvents.toastf("Gifted %s to %s (%+d friendship)%s", [item.display_name, profile.display_name, delta, occasion])
	return delta

func clear() -> void:
	_points.clear()
	_last_talk_day.clear()
	_last_gift_day.clear()

func to_save_data() -> Dictionary:
	return {
		"points": _points.duplicate(true),
		"last_talk_day": _last_talk_day.duplicate(true),
		"last_gift_day": _last_gift_day.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	var points: Variant = data.get("points", {})
	var talk: Variant = data.get("last_talk_day", {})
	var gift: Variant = data.get("last_gift_day", {})
	_points = {}
	_last_talk_day = {}
	_last_gift_day = {}
	if points is Dictionary:
		for raw_key: Variant in points.keys():
			_points[String(raw_key)] = clampi(_safe_int(points[raw_key], 0), 0, POINTS_PER_HEART * MAX_HEARTS)
	var current_day := maxi(WorldClock.day, 1)
	if talk is Dictionary:
		for raw_key: Variant in talk.keys():
			_last_talk_day[String(raw_key)] = clampi(_safe_int(talk[raw_key], current_day), 0, current_day)
	if gift is Dictionary:
		for raw_key: Variant in gift.keys():
			_last_gift_day[String(raw_key)] = clampi(_safe_int(gift[raw_key], current_day), 0, current_day)
	for raw_key: Variant in _points.keys():
		var npc_id := StringName(String(raw_key))
		friendship_changed.emit(npc_id, get_points(npc_id), 0)

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
