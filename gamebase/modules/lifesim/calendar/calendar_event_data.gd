class_name CalendarEventData
extends ContentEntry

const KIND := &"calendar_event"

@export var display_name: String
@export var location_id: StringName
@export var seasons: PackedStringArray = PackedStringArray()
@export_range(0, 28, 1) var day_of_season := 0
@export var days_of_week: PackedInt32Array = PackedInt32Array()
@export_range(0, 1439, 1) var start_minute := 9 * 60
@export_range(1, 1440, 1) var end_minute := 17 * 60

@export_group("Participation Reward")
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

func is_active(day: int, minute_of_day: int) -> bool:
	if not seasons.is_empty() and not seasons.has(GameClock.get_season_name_for_day(day)):
		return false
	if day_of_season > 0 and posmod(maxi(day, 1) - 1, GameClock.DAYS_PER_SEASON) + 1 != day_of_season:
		return false
	if not days_of_week.is_empty() and not days_of_week.has(posmod(maxi(day, 1) - 1, 7)):
		return false
	return minute_of_day >= start_minute and minute_of_day < end_minute

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if location_id != &"" and not registry.has_entry(WorldLocationData.KIND, location_id):
		problems.append("references unknown location '%s'" % location_id)
	if day_of_season < 0 or day_of_season > GameClock.DAYS_PER_SEASON:
		problems.append("has invalid day-of-season %d" % day_of_season)
	if end_minute <= start_minute:
		problems.append("has an invalid time window")
	if reward_money < 0:
		problems.append("has negative reward money")
	for weekday: int in days_of_week:
		if weekday < 0 or weekday > 6:
			problems.append("has invalid weekday %d" % weekday)
	for season: String in seasons:
		if not GameClock.SEASON_NAMES.has(season):
			problems.append("has unknown season '%s'" % season)
	problems.append_array(ItemData.find_amount_problems(reward_items, registry, "rewards", "reward quantity"))
	if reward_skill != &"":
		if not SkillManager.SKILL_IDS.has(reward_skill):
			problems.append("references unknown reward skill '%s'" % reward_skill)
		elif reward_skill_xp <= 0:
			problems.append("has a reward skill without XP")
	return problems
