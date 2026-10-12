class_name GameMenu
extends Control

@onready var content: RichTextLabel = $Panel/Layout/Content
@onready var inventory_button: Button = $Panel/Layout/Tabs/Inventory
@onready var quests_button: Button = $Panel/Layout/Tabs/Quests
@onready var social_button: Button = $Panel/Layout/Tabs/Social
@onready var skills_button: Button = $Panel/Layout/Tabs/Skills
@onready var calendar_button: Button = $Panel/Layout/Tabs/Calendar
@onready var world_button: Button = $Panel/Layout/Tabs/World
@onready var collections_button: Button = $Panel/Layout/Tabs/Collections
@onready var hotbar_editor: HBoxContainer = $Panel/Layout/HotbarEditor
@onready var item_select: OptionButton = $Panel/Layout/HotbarEditor/Item
@onready var slot_select: OptionButton = $Panel/Layout/HotbarEditor/Slot
@onready var assign_button: Button = $Panel/Layout/HotbarEditor/Assign
@onready var collection_claim_button: Button = $Panel/Layout/CollectionClaim
@onready var close_button: Button = $Panel/Layout/Close

var _tab := "inventory"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	inventory_button.pressed.connect(_show_tab.bind("inventory"))
	quests_button.pressed.connect(_show_tab.bind("quests"))
	social_button.pressed.connect(_show_tab.bind("social"))
	skills_button.pressed.connect(_show_tab.bind("skills"))
	calendar_button.pressed.connect(_show_tab.bind("calendar"))
	world_button.pressed.connect(_show_tab.bind("world"))
	collections_button.pressed.connect(_show_tab.bind("collections"))
	assign_button.pressed.connect(_assign_hotbar)
	collection_claim_button.pressed.connect(_claim_first_collection_milestone)
	close_button.pressed.connect(close)
	InventoryState.changed.connect(_refresh_if_open)
	Hotbar.selected_slot_changed.connect(_on_selected_changed)
	Hotbar.changed.connect(_refresh_if_open)
	QuestState.quest_started.connect(_on_quest_changed)
	QuestState.quest_progressed.connect(_on_quest_progress)
	QuestState.quest_completed.connect(_on_quest_changed)
	RelationshipState.friendship_changed.connect(_on_friendship_changed)
	Skills.skill_xp_changed.connect(_on_skill_changed)
	BuffState.buffs_changed.connect(_refresh_if_open)
	WorldClock.day_changed.connect(_on_day_changed)
	WorldClock.minute_changed.connect(_on_minute_changed)
	WeatherState.weather_changed.connect(_on_weather_changed)
	CollectionState.collection_changed.connect(_on_collection_changed)
	CollectionMilestones.milestone_ready.connect(_on_collection_milestone_changed)
	CollectionMilestones.milestone_claimed.connect(_on_collection_milestone_changed)
	DailyContractState.contract_changed.connect(_on_daily_contract_changed)
	TownProjects.project_changed.connect(_on_town_project_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	for button: Button in _tab_buttons():
		button.toggle_mode = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		if visible:
			if not InputLock.is_top(self):
				# A menu over this one has the keys.
				return
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif visible and InputLock.is_top(self) and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	InputLock.lock(&"game_menu", true, self)
	_show_tab(_tab)

func close() -> void:
	if not visible:
		return
	visible = false
	InputLock.unlock(&"game_menu")

func _show_tab(tab: String) -> void:
	_tab = tab
	hotbar_editor.visible = _tab == "inventory"
	collection_claim_button.visible = _tab == "collections" and CollectionMilestones.get_ready_count() > 0
	collection_claim_button.text = tr("Claim Archive Reward (%d)") % CollectionMilestones.get_ready_count()
	match _tab:
		"quests": content.text = _quest_text()
		"social": content.text = _social_text()
		"skills": content.text = _skills_text()
		"calendar": content.text = _calendar_text()
		"world": content.text = _world_text()
		"collections": content.text = _collections_text()
		_:
			content.text = _inventory_text()
			_rebuild_hotbar_editor()
	_update_tab_buttons()

func _inventory_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]%s[/b][/font_size]" % tr("Inventory"), ""])
	var entries := InventoryState.get_entries()
	if entries.is_empty():
		lines.append(tr("Empty"))
	else:
		var selected := Hotbar.get_selected_item_id()
		for entry: Dictionary in entries:
			var item_id := StringName(String(entry["id"]))
			var marker := "→ " if item_id == selected else "  "
			lines.append("%s%s  x%d" % [marker, tr(String(entry["display_name"])), entry["quantity"]])
	lines.append("")
	lines.append(tr("Money: %dg") % PlayerState.money)
	lines.append(tr("HP: %d/%d    Energy: %d/%d") % [PlayerState.health, PlayerState.max_health, PlayerState.energy, PlayerState.max_energy])
	lines.append("")
	lines.append(tr("Use the controls below to bind any carried item to slots 1–9."))
	return "\n".join(lines)

func _quest_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]%s[/b][/font_size]" % tr("Quest Journal"), ""])
	var entries := QuestState.get_journal_entries()
	if entries.is_empty():
		lines.append(tr("No quests yet."))
	for entry: Dictionary in entries:
		var objectives: Array = entry["objectives"]
		var status := tr("Complete")
		if not bool(entry["completed"]) and objectives.size() == 1:
			status = "%d/%d" % [objectives[0]["progress"], objectives[0]["required"]]
		elif not bool(entry["completed"]):
			var met := objectives.filter(func(objective: Dictionary) -> bool: return int(objective["progress"]) >= int(objective["required"])).size()
			status = tr("%d of %d done") % [met, objectives.size()]
		lines.append("[b]%s[/b] — %s" % [tr(String(entry["title"])), status])
		lines.append(tr(String(entry["description"])))
		if not bool(entry["completed"]) and objectives.size() > 1:
			for objective: Dictionary in objectives:
				lines.append("· %s  %d/%d" % [tr(String(objective["description"])), objective["progress"], objective["required"]])
		lines.append("")
	lines.append("[b]%s[/b]" % tr("Town Contract"))
	lines.append(DailyContractState.get_summary())
	return "\n".join(lines)

func _social_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]%s[/b][/font_size]" % tr("Relationships"), ""])
	for profile: NpcProfileData in NpcProfileData.find_all():
		var points := RelationshipState.get_points(profile.id)
		var hearts := RelationshipState.get_hearts(profile.id)
		lines.append(tr("[b]%s[/b] — %s   %d ♥   (%d pts)") % [tr(profile.display_name), tr(profile.role), hearts, points])
	return "\n".join(lines)

func _skills_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]%s[/b][/font_size]" % tr("Skills"), ""])
	for skill: SkillData in SkillData.find_all():
		lines.append(tr("[b]%s[/b]  Lv.%d   %d XP") % [tr(skill.display_name), Skills.get_level(skill.id), Skills.get_xp(skill.id)])
		lines.append("  %s" % Skills.get_perk_summary(skill.id))
	lines.append("")
	lines.append("[b]%s[/b]" % tr("Active Buffs"))
	var buffs := BuffState.get_active_entries()
	if buffs.is_empty():
		lines.append(tr("None"))
	else:
		for entry: Dictionary in buffs:
			lines.append(tr("• %s — %d min") % [tr(String(entry["display_name"])), entry["minutes_remaining"]])
	return "\n".join(lines)

func _calendar_text() -> String:
	var tomorrow := WorldClock.day + 1
	var lines := PackedStringArray([
		"[font_size=18][b]%s[/b][/font_size]" % tr("Calendar"),
		"",
		tr("Today: [b]%s %d[/b] — %s") % [tr(WorldClock.get_season_name()), WorldClock.get_day_of_season(), tr(WeatherState.get_weather_name())],
		tr("Tomorrow: %s %d — %s") % [tr(GameCalendar.current().get_season_name(tomorrow)), GameCalendar.current().get_day_of_season(tomorrow), tr(WeatherState.get_weather_name(tomorrow))],
		"",
		"[b]%s[/b]" % tr("Upcoming events"),
	])
	var any_event := false
	for event: CalendarEventData in CalendarEventData.find_all():
		var event_day := _next_event_day(event, WorldClock.day)
		if event_day < 0:
			continue
		any_event = true
		var location := WorldLocationData.find(event.location_id)
		var location_name := tr(location.display_name) if location != null else tr("World")
		var participation := tr(" · joined this year") if event.has_participation_reward() and EventState.has_claimed_participation(event.id) else ""
		lines.append(tr("• %s%s — %s %d, %02d:%02d @ %s") % [tr(event.display_name), participation, tr(GameCalendar.current().get_season_name(event_day)), GameCalendar.current().get_day_of_season(event_day), event.start_minute / 60, event.start_minute % 60, location_name])
	if not any_event:
		lines.append(tr("No events in the next %d days.") % GameCalendar.current().days_per_season)
	lines.append("")
	lines.append("[b]%s[/b]" % tr("Upcoming birthdays"))
	var birthdays: Array[Dictionary] = []
	for profile: NpcProfileData in NpcProfileData.find_all():
		var birthday_day := _next_birthday_day(profile, WorldClock.day)
		if birthday_day >= 0:
			birthdays.append({"day": birthday_day, "profile": profile})
	birthdays.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["day"]) < int(b["day"]))
	for entry: Dictionary in birthdays:
		var profile: NpcProfileData = entry["profile"]
		var birthday_day := int(entry["day"])
		lines.append(tr("• %s — %s %d") % [tr(profile.display_name), tr(GameCalendar.current().get_season_name(birthday_day)), GameCalendar.current().get_day_of_season(birthday_day)])
	if birthdays.is_empty():
		lines.append(tr("No birthdays in the next %d days.") % GameCalendar.current().days_per_season)
	return "\n".join(lines)

func _world_text() -> String:
	var current := WorldLocationData.find_current(get_tree())
	var lines := PackedStringArray(["[font_size=18][b]%s[/b][/font_size]" % tr("World"), ""])
	for location: WorldLocationData in WorldLocationData.find_all():
		var marker := "→" if current != null and current.id == location.id else "•"
		lines.append("%s [b]%s[/b] — %s" % [marker, tr(location.display_name), _location_type_name(location.type)])
	lines.append("")
	lines.append("[b]%s[/b]" % tr("Residents"))
	for profile: NpcProfileData in NpcProfileData.find_all():
		var home := WorldLocationData.find(profile.home_location_id)
		lines.append("• %s — %s" % [tr(profile.display_name), tr(home.display_name) if home != null else tr("Unknown")])
	lines.append("")
	lines.append("[b]%s[/b]" % tr("Town Projects"))
	for project: TownProjectData in TownProjectData.find_all():
		var location := WorldLocationData.find(project.location_id)
		lines.append("• %s — %s" % [tr(location.display_name) if location != null else tr("Unknown"), TownProjects.get_project_summary(project.id)])
	return "\n".join(lines)

func _collections_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]%s[/b][/font_size]" % tr("Collections"), "", CollectionState.get_summary(), "", "[b]%s[/b]" % tr("Archive Milestones")])
	for milestone: CollectionMilestoneData in CollectionMilestones.get_all_milestones():
		lines.append("• %s" % CollectionMilestones.get_summary(milestone))
	lines.append("")
	lines.append_array(_achievement_lines())
	lines.append("")
	for category: StringName in CollectionService.CATEGORIES:
		var entries := CollectionState.get_category_entries(category)
		lines.append("[b]%s — %d/%d[/b]" % [CollectionState.get_category_name(category), CollectionState.get_discovered_count(category), entries.size()])
		for entry: Dictionary in entries:
			if bool(entry["discovered"]):
				lines.append("  • %s  x%d" % [tr(String(entry["display_name"])), entry["count"]])
			else:
				lines.append("  • ???")
		lines.append("")
	return "\n".join(lines)

# The profile's achievements, which every save shares; a hidden one shows
# nothing of itself until it is unlocked.
func _achievement_lines() -> PackedStringArray:
	var achievements := AchievementData.find_all()
	var lines := PackedStringArray([""])
	var unlocked_count := 0
	for achievement: AchievementData in achievements:
		var unlocked := GameProfile.is_unlocked(achievement.id)
		unlocked_count += 1 if unlocked else 0
		if achievement.hidden and not unlocked:
			lines.append("  ○ ???")
		else:
			lines.append("  %s %s — %s" % ["✓" if unlocked else "○", tr(achievement.display_name), tr(achievement.description)])
	lines[0] = "[b]%s — %d/%d[/b]" % [tr("Achievements"), unlocked_count, achievements.size()]
	return lines

func _rebuild_hotbar_editor() -> void:
	item_select.clear()
	for entry: Dictionary in InventoryState.get_entries():
		var item_id := StringName(String(entry["id"]))
		item_select.add_item("%s x%d" % [tr(String(entry["display_name"])), entry["quantity"]])
		item_select.set_item_metadata(item_select.item_count - 1, String(item_id))
	slot_select.clear()
	for index in Hotbar.slots.size():
		var existing_id := Hotbar.slots[index]
		var existing := ItemData.find(existing_id)
		var existing_name := tr(existing.display_name) if existing != null else (String(existing_id) if existing_id != &"" else tr("Empty"))
		slot_select.add_item("%d: %s" % [index + 1, existing_name])
	slot_select.select(clampi(Hotbar.selected_slot, 0, maxi(slot_select.item_count - 1, 0)))
	assign_button.disabled = item_select.item_count == 0 or slot_select.item_count == 0

func _claim_first_collection_milestone() -> void:
	for milestone: CollectionMilestoneData in CollectionMilestones.get_all_milestones():
		if CollectionMilestones.is_ready(milestone.id):
			CollectionMilestones.claim(milestone.id)
			break
	_show_tab("collections")

func _assign_hotbar() -> void:
	if item_select.selected < 0 or slot_select.selected < 0:
		return
	var item_id := StringName(String(item_select.get_item_metadata(item_select.selected)))
	if item_id == &"" or not InventoryState.has_item(item_id, 1):
		return
	Hotbar.set_slot_item(slot_select.selected, item_id)
	Hotbar.select_slot(slot_select.selected)
	_show_tab("inventory")

func _next_birthday_day(profile: NpcProfileData, from_day: int) -> int:
	if profile == null:
		return -1
	for offset in range(GameCalendar.current().days_per_season):
		var candidate := from_day + offset
		if profile.is_birthday(candidate):
			return candidate
	return -1

func _next_event_day(event: CalendarEventData, from_day: int) -> int:
	if event == null:
		return -1
	for offset in range(GameCalendar.current().days_per_season):
		var candidate := from_day + offset
		if event.is_active(candidate, event.start_minute):
			return candidate
	return -1

func _location_type_name(location_type: WorldLocationData.LocationType) -> String:
	match location_type:
		WorldLocationData.LocationType.INTERIOR: return tr("Interior")
		WorldLocationData.LocationType.WILDERNESS: return tr("Wilderness")
		WorldLocationData.LocationType.DUNGEON: return tr("Dungeon")
		_: return tr("Town")

func _tab_buttons() -> Array[Button]:
	return [inventory_button, quests_button, social_button, skills_button, calendar_button, world_button, collections_button]

func _update_tab_buttons() -> void:
	inventory_button.button_pressed = _tab == "inventory"
	quests_button.button_pressed = _tab == "quests"
	social_button.button_pressed = _tab == "social"
	skills_button.button_pressed = _tab == "skills"
	calendar_button.button_pressed = _tab == "calendar"
	world_button.button_pressed = _tab == "world"
	collections_button.button_pressed = _tab == "collections"
	match _tab:
		"quests": quests_button.grab_focus()
		"social": social_button.grab_focus()
		"skills": skills_button.grab_focus()
		"calendar": calendar_button.grab_focus()
		"world": world_button.grab_focus()
		"collections": collections_button.grab_focus()
		_: inventory_button.grab_focus()

func _on_locale_changed(_locale: String) -> void:
	_refresh_if_open()

func _refresh_if_open() -> void:
	if visible:
		_show_tab(_tab)

func _on_selected_changed(_index: int, _item_id: StringName) -> void:
	_refresh_if_open()

func _on_quest_changed(_quest_id: StringName) -> void:
	_refresh_if_open()

func _on_quest_progress(_quest_id: StringName, _objective: int, _progress: int, _required: int) -> void:
	_refresh_if_open()

func _on_friendship_changed(_npc_id: StringName, _points: int, _delta: int) -> void:
	_refresh_if_open()

func _on_skill_changed(_skill: StringName, _xp: int, _level: int) -> void:
	_refresh_if_open()

func _on_day_changed(_day: int) -> void:
	if visible and (_tab == "calendar" or _tab == "world"):
		_show_tab(_tab)

func _on_weather_changed(_day: int, _weather_id: StringName) -> void:
	if visible and _tab == "calendar":
		_show_tab(_tab)

func _on_minute_changed(_day: int, _minute_of_day: int) -> void:
	if visible and _tab == "skills":
		_show_tab(_tab)

func _on_collection_changed(_category: StringName, _item_id: StringName, _count: int) -> void:
	if visible and _tab == "collections":
		_show_tab(_tab)

func _on_collection_milestone_changed(_milestone_id: StringName) -> void:
	if visible and _tab == "collections":
		_show_tab(_tab)

func _on_daily_contract_changed(_contract: Dictionary) -> void:
	if visible and _tab == "quests":
		_show_tab(_tab)

func _on_town_project_changed(_project_id: StringName, _state: Dictionary) -> void:
	if visible and _tab == "world":
		_show_tab(_tab)
