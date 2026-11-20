class_name NpcProfileData
extends ContentEntry

## A person of the world: who they are (`role`, `background`, `personality`,
## `speaking_style`, which a chat module reads), where they live and stand
## through the day (`schedule_entries`), their birthday, the dialogue they say
## at each number of hearts, and the gifts they love, like and dislike
## (`RelationshipManager`).

const KIND := &"npc"

## How they take an item as a gift, from the worst to the best
## (`taste_of()`).
enum Taste { DISLIKED, NEUTRAL, LIKED, LOVED }
## The friendship a gift of each taste gives, before a birthday doubles it.
const TASTE_POINTS: Dictionary[Taste, int] = {Taste.DISLIKED: -20, Taste.NEUTRAL: 15, Taste.LIKED: 45, Taste.LOVED: 80}

## The name the player reads.
@export var display_name: String
## What they do in the world, in a few words ("Blacksmith").
@export var role: String = "Villager"
## Who they are, how they behave and how they talk, in prose: what a chat
## module tells the model that speaks for them (`NpcContextService`).
@export_multiline var background: String
@export_multiline var personality: String
@export_multiline var speaking_style: String
## Where they live and where they are found most (`WorldLocationData`), for
## their context and the game's menus; where they stand comes from their
## `schedule_entries`.
@export var home_location_id: StringName
@export var default_location_id: StringName
## Whether the NPC chats about the topics the player brings up instead of
## saying its daily lines, in a game with a module that makes chats (npc_ai);
## its heart events play all the same.
@export var ai_enabled := false
## The `WorldState` keys whose values their chat context carries, facts of the
## world they know about.
@export var context_world_keys: Array[StringName] = []

@export_group("Birthday")
## A season of the game's calendar; none ("") for an NPC without a birthday.
@export var birthday_season: String = ""
## The day of `birthday_season` it falls on, from 1.
@export_range(1, 28, 1, "or_greater") var birthday_day := 1

@export_group("Dialogue")
## The dialogue they say from a number of hearts on, as hearts -> title in
## their dialogue: the highest the player has reached takes the place of the
## daily one.
@export var dialogue_titles_by_hearts: Dictionary = {}

@export_group("Presentation")
## The folder of their sprite strips (`DirectionalActorVisual`), and the
## colour their sprite is tinted.
@export_dir var visual_strip_root: String
@export var visual_modulate := Color.WHITE

@export_group("Schedule")
## Where they stand at each time of the day, the season and the weather
## (`NpcScheduleEntry`).
@export var schedule_entries: Array[NpcScheduleEntry] = []

@export_group("Gift Preferences")
## The items (`ItemData`) they love, like and dislike as gifts, and the item
## tags they love and like; a gift they have no feeling for still pleases them
## a little (`friendship_for_gift()`).
@export var loved_items: Array[StringName] = []
@export var liked_items: Array[StringName] = []
@export var disliked_items: Array[StringName] = []
@export var loved_tags: PackedStringArray = PackedStringArray()
@export var liked_tags: PackedStringArray = PackedStringArray()

## The NPC with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> NpcProfileData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as NpcProfileData

## The running game's NPCs, sorted by id.
static func find_all() -> Array[NpcProfileData]:
	var result: Array[NpcProfileData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func is_birthday(target_day: int = -1) -> bool:
	if birthday_season.is_empty():
		return false
	var resolved_day := WorldClock.day if target_day < 1 else target_day
	return GameCalendar.current().get_season_name(resolved_day) == birthday_season and GameCalendar.current().get_day_of_season(resolved_day) == birthday_day

func get_dialogue_title(base_title: String, hearts: int) -> String:
	var best_threshold := -1
	var resolved := base_title
	for raw_key: Variant in dialogue_titles_by_hearts.keys():
		if typeof(raw_key) != TYPE_INT:
			continue
		var threshold := int(raw_key)
		if threshold < 0 or threshold > RelationshipManager.MAX_HEARTS:
			continue
		var raw_title: Variant = dialogue_titles_by_hearts[raw_key]
		if not raw_title is String and not raw_title is StringName:
			continue
		var title := String(raw_title)
		if title.is_empty():
			continue
		if threshold <= hearts and threshold > best_threshold:
			best_threshold = threshold
			resolved = title
	return resolved

## How they take `item` as a gift: an item they love, dislike or like by
## its id, else by one of its tags they love or like, else neither.
func taste_of(item: ItemData) -> Taste:
	if item == null:
		return Taste.NEUTRAL
	if loved_items.has(item.id):
		return Taste.LOVED
	if disliked_items.has(item.id):
		return Taste.DISLIKED
	if liked_items.has(item.id):
		return Taste.LIKED
	for tag: String in loved_tags:
		if item.has_tag(tag):
			return Taste.LOVED
	for tag: String in liked_tags:
		if item.has_tag(tag):
			return Taste.LIKED
	return Taste.NEUTRAL

## The friendship a gift of `item` gives them (`TASTE_POINTS`), 0 for none.
func friendship_for_gift(item: ItemData) -> int:
	return 0 if item == null else TASTE_POINTS[taste_of(item)]

## Where they are and what they do now, by their schedule, as the player reads
## it ("Riverside Town · Morning walk"; `NpcSchedule.find_entry()`): the
## entry's location, else their default one, and its activity; "" without a
## schedule for now.
func describe_whereabouts(day: int = -1, minute_of_day: int = -1) -> String:
	var entry := NpcSchedule.find_entry(schedule_entries, WorldClock.minute_of_day if minute_of_day < 0 else minute_of_day, day)
	if entry == null:
		return ""
	var location := WorldLocationData.find(entry.location_id if entry.location_id != &"" else default_location_id)
	var activity := String(TranslationServer.translate(entry.activity))
	if location == null:
		return activity
	return "%s · %s" % [TranslationServer.translate(location.display_name), activity]

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for list_name: String in ["loved_items", "liked_items", "disliked_items"]:
		for item_id: StringName in get(list_name):
			if not registry.has_entry(ItemData.KIND, item_id):
				problems.append("%s references unknown item '%s'" % [list_name, item_id])
	for raw_threshold: Variant in dialogue_titles_by_hearts:
		if typeof(raw_threshold) != TYPE_INT:
			problems.append("dialogue threshold '%s' is not an integer" % raw_threshold)
			continue
		var threshold := int(raw_threshold)
		if threshold < 0 or threshold > RelationshipManager.MAX_HEARTS:
			problems.append("dialogue threshold %d is outside heart range" % threshold)
		var title: Variant = dialogue_titles_by_hearts[raw_threshold]
		if (not title is String and not title is StringName) or String(title).is_empty():
			problems.append("dialogue threshold %d has an invalid title" % threshold)
	if not birthday_season.is_empty():
		if not GameCalendar.current().has_season(birthday_season):
			problems.append("has unknown birthday season '%s'" % birthday_season)
		if birthday_day < 1 or birthday_day > GameCalendar.current().days_per_season:
			problems.append("has invalid birthday day %d" % birthday_day)
	for location_id: StringName in [home_location_id, default_location_id]:
		if location_id != &"" and not registry.has_entry(WorldLocationData.KIND, location_id):
			problems.append("references unknown location '%s'" % location_id)
	for entry: NpcScheduleEntry in schedule_entries:
		if entry == null:
			continue
		if entry.location_id != &"" and not registry.has_entry(WorldLocationData.KIND, entry.location_id):
			problems.append("schedule references unknown location '%s'" % entry.location_id)
		for weekday: int in entry.days_of_week:
			if weekday < 0 or weekday >= GameCalendar.current().days_per_week:
				problems.append("schedule has invalid weekday %d" % weekday)
		for season: String in entry.seasons:
			if not GameCalendar.current().has_season(season):
				problems.append("schedule has unknown season '%s'" % season)
		for weather_id: StringName in entry.allowed_weather:
			if not registry.has_entry(WeatherData.KIND, weather_id):
				problems.append("schedule has unknown weather '%s'" % weather_id)
	return problems
