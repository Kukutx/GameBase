class_name CalendarEventData
extends ContentEntry

## A happening of the calendar, a fair or a market: on in its `seasons`, on
## its `day_of_season` and `days_of_week`, from `start_minute` to `end_minute`,
## at its location (`CalendarEventManager`). While it is on, the player may
## claim its participation reward once a year at a `CalendarEventBooth`, and
## content asks whether it is on with `EVENT_ACTIVE <event>`.

const KIND := &"calendar_event"

## The name the player reads.
@export var display_name: String
## The location (`WorldLocationData`) it is held in, whose booths may give its
## reward; empty, anywhere.
@export var location_id: StringName
## The seasons of the game's calendar it is on in; empty, every season.
@export var seasons: PackedStringArray = PackedStringArray()
## The day of the season it is on, from 1; 0, every day.
@export_range(0, 28, 1, "or_greater") var day_of_season := 0
## The days of the week it is on, from 0 for the first; empty, every day.
@export var days_of_week: PackedInt32Array = PackedInt32Array()
## When it begins and ends, in minutes after midnight; it is over at
## `end_minute`.
@export_range(0, 1439, 1) var start_minute := 9 * 60
@export_range(1, 1440, 1) var end_minute := 17 * 60

@export_group("Participation Reward")
## What taking part gives once a year: money, items (item id -> count) and
## experience of a skill (`SkillData`).
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}
@export var reward_skill: StringName
@export_range(0, 9999, 1) var reward_skill_xp := 0

## The calendar event with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> CalendarEventData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as CalendarEventData

## The running game's calendar events, sorted by id.
static func find_all() -> Array[CalendarEventData]:
	var result: Array[CalendarEventData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func has_participation_reward() -> bool:
	return reward_money > 0 or not reward_items.is_empty() or (reward_skill != &"" and reward_skill_xp > 0)

## Whether the event is on at minute `minute_of_day` of `day`.
func is_active(day: int, minute_of_day: int) -> bool:
	return is_held_on(day) and minute_of_day >= start_minute and minute_of_day < end_minute

## Whether the event is held on `day`, at any of its hours.
func is_held_on(day: int) -> bool:
	if not seasons.is_empty() and not seasons.has(GameCalendar.current().get_season_name(day)):
		return false
	if day_of_season > 0 and GameCalendar.current().get_day_of_season(maxi(day, 1)) != day_of_season:
		return false
	return days_of_week.is_empty() or days_of_week.has(GameCalendar.current().get_weekday(day))

## The first day of the `days` days from `from_day` on which the event is
## held and not yet over at minute `from_minute` of `from_day` (an event over
## for today counts from its next day); -1 for none.
func next_day(from_day: int, days: int, from_minute := 0) -> int:
	for offset: int in days:
		var day := from_day + offset
		if is_held_on(day) and (offset > 0 or from_minute < end_minute):
			return day
	return -1

## The running game's events held in the `days` days from minute
## `from_minute` of `from_day` (`next_day()`), each as {"day": the day it is
## next held, "event": it}, soonest first, then by the minute it starts.
static func find_upcoming(from_day: int, days: int, from_minute := 0) -> Array[Dictionary]:
	var upcoming: Array[Dictionary] = []
	for event: CalendarEventData in find_all():
		var day := event.next_day(from_day, days, from_minute)
		if day >= 0:
			upcoming.append({"day": day, "event": event})
	upcoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: CalendarEventData = a["event"]
		var second: CalendarEventData = b["event"]
		if int(a["day"]) != int(b["day"]):
			return int(a["day"]) < int(b["day"])
		if first.start_minute != second.start_minute:
			return first.start_minute < second.start_minute
		return String(first.id) < String(second.id))
	return upcoming

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if location_id != &"" and not registry.has_entry(WorldLocationData.KIND, location_id):
		problems.append("references unknown location '%s'" % location_id)
	if day_of_season < 0 or day_of_season > GameCalendar.current().days_per_season:
		problems.append("has invalid day-of-season %d" % day_of_season)
	if end_minute <= start_minute:
		problems.append("has an invalid time window")
	if reward_money < 0:
		problems.append("has negative reward money")
	for weekday: int in days_of_week:
		if weekday < 0 or weekday >= GameCalendar.current().days_per_week:
			problems.append("has invalid weekday %d" % weekday)
	for season: String in seasons:
		if not GameCalendar.current().has_season(season):
			problems.append("has unknown season '%s'" % season)
	problems.append_array(ItemData.find_amount_problems(reward_items, registry, "rewards", "reward quantity"))
	if reward_skill != &"":
		if not registry.has_entry(SkillData.KIND, reward_skill):
			problems.append("references unknown reward skill '%s'" % reward_skill)
		elif reward_skill_xp <= 0:
			problems.append("has a reward skill without XP")
	return problems
