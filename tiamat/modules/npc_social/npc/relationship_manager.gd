class_name RelationshipManager
extends Node

## The player's friendship with each NPC, in points (`POINTS_PER_HEART` make a
## heart, up to `MAX_HEARTS`), and the daily limits on raising it: the first
## talk of the day with an NPC gives 10 points, and each NPC takes one gift a
## day.
##
## A gift's points come from the NPC's `NpcProfileData`, doubled on its
## birthday, and the `gift_friendship` stat (`GameStats`) scales a gift it
## likes; tools, seeds and quest items are not gifts (`is_gift()`). Points
## stay between 0 and the maximum.
## They are saved with the game, with the day of each NPC's last talk and gift,
## and a new game starts at 0. `friendship_changed` fires on every change, and
## for each NPC when a save loads.
##
## A gift tells the player how the NPC takes it (`NpcProfileData.Taste`), and
## that is kept with the rest, so a menu tells what each NPC was found to love,
## like and dislike (`describe_known_tastes()`), and an item who was found to
## take it how (`describe_known_takers()`).

signal friendship_changed(npc_id: StringName, points: int, delta: int)

const POINTS_PER_HEART := 250
const MAX_HEARTS := 10

var _points: Dictionary = {}
var _last_talk_day: Dictionary = {}
var _last_gift_day: Dictionary = {}
# npc id -> {item id -> NpcProfileData.Taste}: what each gift told the player.
var _known_tastes: Dictionary = {}

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

## Whether the player talked with `npc_id` today.
func has_talked_today(npc_id: StringName) -> bool:
	return int(_last_talk_day.get(String(npc_id), 0)) == WorldClock.day

## Whether the player gave `npc_id` a gift today.
func has_given_gift_today(npc_id: StringName) -> bool:
	return int(_last_gift_day.get(String(npc_id), 0)) == WorldClock.day

## How `npc_id` took `item_id` as a gift (`NpcProfileData.Taste`), or -1 while
## the player has not given them one.
func get_known_taste(npc_id: StringName, item_id: StringName) -> int:
	var tastes: Dictionary = _known_tastes.get(String(npc_id), {})
	return int(tastes.get(String(item_id), -1))

## The items the player found `npc_id` takes as gifts of `taste`, by id.
func get_items_known_as(npc_id: StringName, taste: NpcProfileData.Taste) -> Array[StringName]:
	var items: Array[StringName] = []
	var tastes: Dictionary = _known_tastes.get(String(npc_id), {})
	for raw_id: Variant in tastes:
		if int(tastes[raw_id]) == taste:
			items.append(StringName(String(raw_id)))
	items.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return items

## What the player found of how `npc_id` takes gifts, a line for each taste
## with any item: "Loves: Berry, Ruby", then likes, neutral, dislikes.
func describe_known_tastes(npc_id: StringName) -> PackedStringArray:
	var lines := PackedStringArray()
	var formats := {
		NpcProfileData.Taste.LOVED: tr("Loves: %s"),
		NpcProfileData.Taste.LIKED: tr("Likes: %s"),
		NpcProfileData.Taste.NEUTRAL: tr("Neutral: %s"),
		NpcProfileData.Taste.DISLIKED: tr("Dislikes: %s"),
	}
	for taste: NpcProfileData.Taste in formats:
		var names := PackedStringArray()
		for item_id: StringName in get_items_known_as(npc_id, taste):
			var item := ItemData.find(item_id)
			if item != null:
				names.append(tr(item.display_name))
		if not names.is_empty():
			lines.append(String(formats[taste]) % GameText.list(names))
	return lines

## The pause menu's Townsfolk: each NPC with their role and hearts, where they
## are and what they do now (`NpcProfileData.describe_whereabouts()`), today's
## talk and gift, and what the gifts given told of them; nothing without NPCs.
func describe_townsfolk() -> PackedStringArray:
	var lines := PackedStringArray()
	for profile: NpcProfileData in NpcProfileData.find_all():
		var hearts := get_hearts(profile.id)
		lines.append("%s — %s · %s" % [tr(profile.display_name), tr(profile.role), tr_n("%d heart", "%d hearts", hearts) % hearts])
		for line: String in describe_day(profile):
			lines.append("  " + line)
	return lines

## What `profile`'s NPC is up to today, a line each: where they are now
## ("Now: Riverside Town · Morning walk"), their birthday when it is today,
## today's talk and gift, then what the gifts given told of them
## (`describe_known_tastes()`).
func describe_day(profile: NpcProfileData) -> PackedStringArray:
	var lines := PackedStringArray()
	var now := profile.describe_whereabouts()
	if not now.is_empty():
		lines.append(tr("Now: %s") % now)
	if profile.is_birthday():
		lines.append(tr("Their birthday: a gift counts twice"))
	var today := PackedStringArray()
	if has_talked_today(profile.id):
		today.append(tr("Talked today"))
	if has_given_gift_today(profile.id):
		today.append(tr("Gift given today"))
	if not today.is_empty():
		lines.append(GameText.list(today))
	lines.append_array(describe_known_tastes(profile.id))
	return lines

## What the player found of how each NPC takes `item_id` as a gift, the NPCs
## in their order: "Mira loves it", "Rowan dislikes it".
func describe_known_takers(item_id: StringName) -> PackedStringArray:
	var formats := {
		NpcProfileData.Taste.LOVED: tr("%s loves it"),
		NpcProfileData.Taste.LIKED: tr("%s likes it"),
		NpcProfileData.Taste.NEUTRAL: tr("%s doesn't mind it"),
		NpcProfileData.Taste.DISLIKED: tr("%s dislikes it"),
	}
	var parts := PackedStringArray()
	for profile: NpcProfileData in NpcProfileData.find_all():
		var taste := get_known_taste(profile.id, item_id)
		if formats.has(taste):
			parts.append(String(formats[taste]) % tr(profile.display_name))
	return parts

## Whether `item` can be given as a gift: no tool, seed or quest item.
static func is_gift(item: ItemData) -> bool:
	return item != null and item.kind != ItemData.Kind.TOOL and item.kind != ItemData.Kind.SEED and item.kind != ItemData.Kind.QUEST

func give_gift(profile: NpcProfileData, item_id: StringName) -> int:
	if profile == null or profile.id == &"":
		return 0
	var key := String(profile.id)
	if int(_last_gift_day.get(key, 0)) == WorldClock.day:
		GameEvents.toastf("You already gave %s a gift today", [profile.display_name])
		return 0
	var item := ItemData.find(item_id)
	if not is_gift(item):
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
		delta = roundi(GameStats.apply(&"gift_friendship", delta))
	add_friendship(profile.id, delta)
	var tastes: Dictionary = _known_tastes.get(key, {})
	tastes[String(item_id)] = profile.taste_of(item)
	_known_tastes[key] = tastes
	NpcSocialEvents.gift_given.emit(profile.id, item_id, delta)
	var occasion := " · Birthday!" if birthday else ""
	GameEvents.toastf("Gifted %s to %s (%+d friendship)%s", [item.display_name, profile.display_name, delta, occasion])
	return delta

func clear() -> void:
	_points.clear()
	_last_talk_day.clear()
	_last_gift_day.clear()
	_known_tastes.clear()

func to_save_data() -> Dictionary:
	return {
		"points": _points.duplicate(true),
		"last_talk_day": _last_talk_day.duplicate(true),
		"last_gift_day": _last_gift_day.duplicate(true),
		"known_tastes": _known_tastes.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	var points: Variant = data.get("points", {})
	var talk: Variant = data.get("last_talk_day", {})
	var gift: Variant = data.get("last_gift_day", {})
	var known: Variant = data.get("known_tastes", {})
	_points = {}
	_last_talk_day = {}
	_last_gift_day = {}
	_known_tastes = {}
	# A save from before tastes were kept has none.
	if known is Dictionary:
		for raw_npc: Variant in known.keys():
			var raw_tastes: Variant = known[raw_npc]
			if not raw_tastes is Dictionary:
				continue
			var tastes := {}
			for raw_item: Variant in raw_tastes.keys():
				var taste := SaveValues.whole_number_or(raw_tastes[raw_item], -1)
				if taste >= NpcProfileData.Taste.DISLIKED and taste <= NpcProfileData.Taste.LOVED:
					tastes[String(raw_item)] = taste
			if not tastes.is_empty():
				_known_tastes[String(raw_npc)] = tastes
	if points is Dictionary:
		for raw_key: Variant in points.keys():
			_points[String(raw_key)] = clampi(SaveValues.whole_number_or(points[raw_key], 0), 0, POINTS_PER_HEART * MAX_HEARTS)
	var current_day := maxi(WorldClock.day, 1)
	if talk is Dictionary:
		for raw_key: Variant in talk.keys():
			_last_talk_day[String(raw_key)] = clampi(SaveValues.whole_number_or(talk[raw_key], current_day), 0, current_day)
	if gift is Dictionary:
		for raw_key: Variant in gift.keys():
			_last_gift_day[String(raw_key)] = clampi(SaveValues.whole_number_or(gift[raw_key], current_day), 0, current_day)
	for raw_key: Variant in _points.keys():
		var npc_id := StringName(String(raw_key))
		friendship_changed.emit(npc_id, get_points(npc_id), 0)
