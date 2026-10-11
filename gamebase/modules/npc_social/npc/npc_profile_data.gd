class_name NpcProfileData
extends ContentEntry

@export var display_name: String
@export var role: String = "Villager"
@export_multiline var background: String
@export_multiline var personality: String
@export_multiline var speaking_style: String
@export var home_location_id: StringName
@export var default_location_id: StringName
@export var ai_enabled := true
@export var context_world_keys: Array[StringName] = []

@export_group("Birthday")
@export var birthday_season: String = "Spring"
@export_range(1, 28, 1) var birthday_day := 1

@export_group("Dialogue")
@export var dialogue_titles_by_hearts: Dictionary = {}

@export_group("Presentation")
@export_dir var visual_strip_root: String
@export var visual_modulate := Color.WHITE

@export_group("Schedule")
@export var schedule_entries: Array[NpcScheduleEntry] = []

@export_group("Gift Preferences")
@export var loved_items: Array[StringName] = []
@export var liked_items: Array[StringName] = []
@export var disliked_items: Array[StringName] = []
@export var loved_tags: PackedStringArray = PackedStringArray()
@export var liked_tags: PackedStringArray = PackedStringArray()

func is_birthday(target_day: int = -1) -> bool:
	var resolved_day := WorldClock.day if target_day < 1 else target_day
	return GameClock.get_season_name_for_day(resolved_day) == birthday_season and posmod(resolved_day - 1, GameClock.DAYS_PER_SEASON) + 1 == birthday_day

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

func friendship_for_gift(item: ItemData) -> int:
	if item == null:
		return 0
	if loved_items.has(item.id):
		return 80
	if disliked_items.has(item.id):
		return -20
	if liked_items.has(item.id):
		return 45
	for tag: String in loved_tags:
		if item.has_tag(tag):
			return 80
	for tag: String in liked_tags:
		if item.has_tag(tag):
			return 45
	return 15
