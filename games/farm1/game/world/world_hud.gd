class_name WorldHud
extends CanvasLayer

@onready var clock_label: Label = $Clock
@onready var stats_label: Label = $Stats
@onready var quest_label: Label = $Quest
@onready var skills_label: Label = $Skills
@onready var hotbar_label: Label = $Hotbar
@onready var inventory_label: Label = $Inventory
@onready var status_label: StatusLine = $Status
@onready var fishing_label: Label = $FishingStatus
@onready var buffs_label: Label = $Buffs
@onready var info_label: Label = $Info

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_time_changed)
	WeatherState.weather_changed.connect(_on_weather_changed)
	EventState.active_events_changed.connect(_refresh_clock)
	InventoryState.changed.connect(_refresh_inventory)
	PlayerState.energy_changed.connect(_on_energy_changed)
	PlayerState.health_changed.connect(_on_health_changed)
	PlayerState.money_changed.connect(_on_money_changed)
	Hotbar.selected_slot_changed.connect(_on_selected_changed)
	Hotbar.changed.connect(_refresh_hotbar)
	QuestState.quest_started.connect(_on_quest_event)
	QuestState.quest_progressed.connect(_on_quest_progress)
	QuestState.quest_completed.connect(_on_quest_event)
	Skills.skill_xp_changed.connect(_on_skill_changed)
	BuffState.buffs_changed.connect(_refresh_buffs)
	FishingState.cast_state_changed.connect(_on_fishing_state_changed)
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)
	InputPrompts.input_method_changed.connect(_on_input_method_changed)
	GameSettings.controls_changed.connect(_refresh_controls_hint)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh_all()
	_refresh_fishing()

func _unhandled_input(event: InputEvent) -> void:
	# A development shortcut: exported release builds never skip time.
	if OS.is_debug_build() and event.is_action_pressed("debug_advance_time"):
		WorldClock.advance_minutes(60)
		_show_status(tr("Advanced time by 1 hour"))
		get_viewport().set_input_as_handled()

func _refresh_all() -> void:
	_refresh_clock()
	_refresh_stats()
	_refresh_quest()
	_refresh_skills()
	_refresh_hotbar()
	_refresh_inventory()
	_refresh_buffs()
	_refresh_controls_hint()

func _on_time_changed(_day: int, _minute_of_day: int) -> void:
	_refresh_clock()
	_refresh_buffs()

func _on_weather_changed(_day: int, _weather: GameWeatherSystem.Weather) -> void:
	_refresh_clock()

func _on_energy_changed(_current: int, _maximum: int) -> void:
	_refresh_stats()

func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh_stats()

func _on_money_changed(_amount: int) -> void:
	_refresh_stats()

func _on_selected_changed(_index: int, _item_id: StringName) -> void:
	_refresh_hotbar()

func _on_quest_event(_quest_id: StringName) -> void:
	_refresh_quest()

func _on_quest_progress(_quest_id: StringName, _objective: int, _progress: int, _required: int) -> void:
	_refresh_quest()

func _on_skill_changed(_skill: StringName, _xp: int, _level: int) -> void:
	_refresh_skills()

func _on_fishing_state_changed(_state: FishingService.CastState, _message: String) -> void:
	_refresh_fishing()

func _on_save_completed(_success: bool, message: String) -> void:
	_show_status(message)

func _on_load_completed(success: bool, message: String) -> void:
	_show_status(message)
	if success:
		_refresh_all()
		_refresh_fishing()

func _on_input_method_changed(_using_gamepad: bool) -> void:
	_refresh_controls_hint()

func _on_locale_changed(_locale: String) -> void:
	_refresh_all()
	_refresh_fishing()

func _refresh_clock() -> void:
	if not is_inside_tree():
		return
	var location := WorldLocationData.find_current(get_tree())
	var location_id := location.id if location != null else &""
	var event_summary := EventState.get_summary(location_id)
	clock_label.text = "%s · %s" % [WorldClock.get_calendar_text(), tr(WeatherState.get_weather_name())]
	if not event_summary.is_empty():
		clock_label.text += " · " + event_summary

func _refresh_stats() -> void:
	stats_label.text = tr("HP %d/%d   ·   Energy %d/%d   ·   %dg") % [PlayerState.health, PlayerState.max_health, PlayerState.energy, PlayerState.max_energy, PlayerState.money]

func _refresh_quest() -> void:
	quest_label.text = tr("Quest: %s") % QuestState.get_active_summary()

func _refresh_skills() -> void:
	skills_label.text = Skills.get_summary()

func _refresh_hotbar() -> void:
	hotbar_label.text = Hotbar.get_text()

func _refresh_inventory() -> void:
	inventory_label.text = InventoryState.get_summary(6)

func _refresh_buffs() -> void:
	var summary := BuffState.get_summary()
	buffs_label.text = tr("Buffs: %s") % summary if not summary.is_empty() else ""
	buffs_label.visible = not buffs_label.text.is_empty()

func _refresh_controls_hint() -> void:
	if info_label == null:
		return
	var gamepad := InputPrompts.using_gamepad
	info_label.text = tr("%s move · %s interact/reel · %s tool/item · %s gift · %s pack · %s menu · %s hotbar · %s/%s save/load") % [
		InputPrompts.get_move_prompt(),
		InputPrompts.get_action_prompt(&"interact"),
		InputPrompts.get_action_prompt(&"use_tool"),
		InputPrompts.get_action_prompt(&"give_gift"),
		InputPrompts.get_action_prompt(&"remove_building"),
		InputPrompts.get_action_prompt(&"open_menu"),
		InputPrompts.get_actions_prompt([&"hotbar_prev", &"hotbar_next"]) if gamepad else tr("1–9"),
		InputPrompts.get_action_prompt(&"quick_save"),
		InputPrompts.get_action_prompt(&"quick_load"),
	]

func _refresh_fishing() -> void:
	fishing_label.text = FishingState.get_status_text()
	fishing_label.visible = not fishing_label.text.is_empty()

func _show_status(message: String) -> void:
	status_label.show_message(message)
