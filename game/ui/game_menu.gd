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
	PlayerState.selected_slot_changed.connect(_on_selected_changed)
	PlayerState.hotbar_changed.connect(_refresh_if_open)
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		if visible:
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	get_tree().paused = true
	_show_tab(_tab)

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false

func _show_tab(tab: String) -> void:
	_tab = tab
	hotbar_editor.visible = _tab == "inventory"
	collection_claim_button.visible = _tab == "collections" and CollectionMilestones.get_ready_count() > 0
	collection_claim_button.text = "Claim Archive Reward (%d)" % CollectionMilestones.get_ready_count()
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
	var lines := PackedStringArray(["[font_size=18][b]Inventory[/b][/font_size]", ""])
	var entries := InventoryState.get_entries()
	if entries.is_empty():
		lines.append("Empty")
	else:
		var selected := PlayerState.get_selected_item_id()
		for entry: Dictionary in entries:
			var item_id := StringName(String(entry["id"]))
			var marker := "→ " if item_id == selected else "  "
			var legacy_note := "  [legacy content]" if not bool(entry.get("known", true)) else ""
			lines.append("%s%s  x%d%s" % [marker, entry["display_name"], entry["quantity"], legacy_note])
	lines.append("")
	lines.append("Money: %dg" % PlayerState.money)
	lines.append("HP: %d/%d    Energy: %d/%d" % [PlayerState.health, PlayerState.max_health, PlayerState.energy, PlayerState.max_energy])
	lines.append("")
	lines.append("Use the controls below to bind any carried item to slots 1–9.")
	return "\n".join(lines)

func _quest_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]Quest Journal[/b][/font_size]", ""])
	var entries := QuestState.get_journal_entries()
	if entries.is_empty():
		lines.append("No quests yet.")
	for entry: Dictionary in entries:
		var status := "Complete" if bool(entry["completed"]) else "%d/%d" % [entry["progress"], entry["required"]]
		lines.append("[b]%s[/b] — %s" % [entry["title"], status])
		lines.append(String(entry["description"]))
		lines.append("")
	lines.append("[b]Town Contract[/b]")
	lines.append(DailyContractState.get_summary())
	return "\n".join(lines)

func _social_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]Relationships[/b][/font_size]", ""])
	for profile: NpcProfileData in NpcCatalog.get_all_profiles():
		var points := RelationshipState.get_points(profile.id)
		var hearts := RelationshipState.get_hearts(profile.id)
		lines.append("[b]%s[/b] — %s   %d ♥   (%d pts)" % [profile.display_name, profile.role, hearts, points])
	return "\n".join(lines)

func _skills_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]Skills[/b][/font_size]", ""])
	for skill: StringName in [SkillManager.FARMING, SkillManager.FORAGING, SkillManager.FISHING, SkillManager.MINING, SkillManager.COMBAT, SkillManager.SOCIAL]:
		lines.append("[b]%s[/b]  Lv.%d   %d XP" % [String(skill).capitalize(), Skills.get_level(skill), Skills.get_xp(skill)])
		lines.append("  %s" % Skills.get_perk_summary(skill))
	lines.append("")
	lines.append("[b]Active Buffs[/b]")
	var buffs := BuffState.get_active_entries()
	if buffs.is_empty():
		lines.append("None")
	else:
		for entry: Dictionary in buffs:
			lines.append("• %s — %d min" % [entry["display_name"], entry["minutes_remaining"]])
	return "\n".join(lines)

func _calendar_text() -> String:
	var tomorrow := WorldClock.day + 1
	var lines := PackedStringArray([
		"[font_size=18][b]Calendar[/b][/font_size]",
		"",
		"Today: [b]%s %d[/b] — %s" % [WorldClock.get_season_name(), WorldClock.get_day_of_season(), WeatherState.get_weather_name()],
		"Tomorrow: %s %d — %s" % [GameClock.get_season_name_for_day(tomorrow), posmod(tomorrow - 1, GameClock.DAYS_PER_SEASON) + 1, WeatherState.get_weather_name(WeatherState.get_weather_for_day(tomorrow))],
		"",
		"[b]Upcoming events[/b]",
	])
	var any_event := false
	for event: CalendarEventData in ContentDB.get_all_calendar_events():
		var event_day := _next_event_day(event, WorldClock.day)
		if event_day < 0:
			continue
		any_event = true
		var location := ContentDB.get_location(event.location_id)
		var location_name := location.display_name if location != null else "World"
		var participation := " · joined this year" if event.has_participation_reward() and EventState.has_claimed_participation(event.id) else ""
		lines.append("• %s%s — %s %d, %02d:%02d @ %s" % [event.display_name, participation, GameClock.get_season_name_for_day(event_day), posmod(event_day - 1, GameClock.DAYS_PER_SEASON) + 1, event.start_minute / 60, event.start_minute % 60, location_name])
	if not any_event:
		lines.append("No events in the next 28 days.")
	lines.append("")
	lines.append("[b]Upcoming birthdays[/b]")
	var birthdays: Array[Dictionary] = []
	for profile: NpcProfileData in ContentDB.get_all_npcs():
		var birthday_day := _next_birthday_day(profile, WorldClock.day)
		if birthday_day >= 0:
			birthdays.append({"day": birthday_day, "profile": profile})
	birthdays.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["day"]) < int(b["day"]))
	for entry: Dictionary in birthdays:
		var profile: NpcProfileData = entry["profile"]
		var birthday_day := int(entry["day"])
		lines.append("• %s — %s %d" % [profile.display_name, GameClock.get_season_name_for_day(birthday_day), posmod(birthday_day - 1, GameClock.DAYS_PER_SEASON) + 1])
	if birthdays.is_empty():
		lines.append("No birthdays in the next 28 days.")
	return "\n".join(lines)

func _world_text() -> String:
	var current := ContentDB.get_current_location(get_tree())
	var lines := PackedStringArray(["[font_size=18][b]World[/b][/font_size]", ""])
	for location: WorldLocationData in ContentDB.get_all_locations():
		var marker := "→" if current != null and current.id == location.id else "•"
		lines.append("%s [b]%s[/b] — %s" % [marker, location.display_name, _location_type_name(location.type)])
	lines.append("")
	lines.append("[b]Residents[/b]")
	for profile: NpcProfileData in ContentDB.get_all_npcs():
		var home := ContentDB.get_location(profile.home_location_id)
		lines.append("• %s — %s" % [profile.display_name, home.display_name if home != null else "Unknown"])
	lines.append("")
	lines.append("[b]Town Projects[/b]")
	for project: TownProjectData in ContentDB.get_all_town_projects():
		var location := ContentDB.get_location(project.location_id)
		lines.append("• %s — %s" % [location.display_name if location != null else "Unknown", TownProjects.get_project_summary(project.id)])
	return "\n".join(lines)

func _collections_text() -> String:
	var lines := PackedStringArray(["[font_size=18][b]Collections[/b][/font_size]", "", CollectionState.get_summary(), "", "[b]Archive Milestones[/b]"])
	for milestone: CollectionMilestoneData in CollectionMilestones.get_all_milestones():
		lines.append("• %s" % CollectionMilestones.get_summary(milestone))
	lines.append("")
	for category: StringName in CollectionService.CATEGORIES:
		var entries := CollectionState.get_category_entries(category)
		lines.append("[b]%s — %d/%d[/b]" % [CollectionState.get_category_name(category), CollectionState.get_discovered_count(category), entries.size()])
		for entry: Dictionary in entries:
			if bool(entry["discovered"]):
				lines.append("  • %s  x%d" % [entry["display_name"], entry["count"]])
			else:
				lines.append("  • ???")
		lines.append("")
	return "\n".join(lines)

func _rebuild_hotbar_editor() -> void:
	item_select.clear()
	for entry: Dictionary in InventoryState.get_entries():
		if not bool(entry.get("known", true)):
			continue
		var item_id := StringName(String(entry["id"]))
		item_select.add_item("%s x%d" % [entry["display_name"], entry["quantity"]])
		item_select.set_item_metadata(item_select.item_count - 1, String(item_id))
	slot_select.clear()
	for index in PlayerState.hotbar.size():
		var existing_id := PlayerState.hotbar[index]
		var existing := ItemCatalog.get_item(existing_id)
		var existing_name := existing.display_name if existing != null else (String(existing_id) if existing_id != &"" else "Empty")
		slot_select.add_item("%d: %s" % [index + 1, existing_name])
	slot_select.select(clampi(PlayerState.selected_slot, 0, maxi(slot_select.item_count - 1, 0)))
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
	PlayerState.set_hotbar_item(slot_select.selected, item_id)
	PlayerState.select_slot(slot_select.selected)
	_show_tab("inventory")

func _next_birthday_day(profile: NpcProfileData, from_day: int) -> int:
	if profile == null:
		return -1
	for offset in range(GameClock.DAYS_PER_SEASON):
		var candidate := from_day + offset
		if profile.is_birthday(candidate):
			return candidate
	return -1

func _next_event_day(event: CalendarEventData, from_day: int) -> int:
	if event == null:
		return -1
	for offset in range(28):
		var candidate := from_day + offset
		if event.is_active(candidate, event.start_minute):
			return candidate
	return -1

func _location_type_name(location_type: WorldLocationData.LocationType) -> String:
	match location_type:
		WorldLocationData.LocationType.INTERIOR: return "Interior"
		WorldLocationData.LocationType.WILDERNESS: return "Wilderness"
		WorldLocationData.LocationType.DUNGEON: return "Dungeon"
		_: return "Town"

func _update_tab_buttons() -> void:
	inventory_button.disabled = _tab == "inventory"
	quests_button.disabled = _tab == "quests"
	social_button.disabled = _tab == "social"
	skills_button.disabled = _tab == "skills"
	calendar_button.disabled = _tab == "calendar"
	world_button.disabled = _tab == "world"
	collections_button.disabled = _tab == "collections"
	match _tab:
		"quests": quests_button.grab_focus()
		"social": social_button.grab_focus()
		"skills": skills_button.grab_focus()
		"calendar": calendar_button.grab_focus()
		"world": world_button.grab_focus()
		"collections": collections_button.grab_focus()
		_: inventory_button.grab_focus()

func _refresh_if_open() -> void:
	if visible:
		_show_tab(_tab)

func _on_selected_changed(_index: int, _item_id: StringName) -> void:
	_refresh_if_open()

func _on_quest_changed(_quest_id: StringName) -> void:
	_refresh_if_open()

func _on_quest_progress(_quest_id: StringName, _progress: int, _required: int) -> void:
	_refresh_if_open()

func _on_friendship_changed(_npc_id: StringName, _points: int, _delta: int) -> void:
	_refresh_if_open()

func _on_skill_changed(_skill: StringName, _xp: int, _level: int) -> void:
	_refresh_if_open()

func _on_day_changed(_day: int) -> void:
	if visible and (_tab == "calendar" or _tab == "world"):
		_show_tab(_tab)

func _on_weather_changed(_day: int, _weather: GameWeatherSystem.Weather) -> void:
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
