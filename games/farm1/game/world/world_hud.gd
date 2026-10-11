class_name WorldHud
extends CanvasLayer

@onready var clock_label: Label = $Clock
@onready var stats_label: Label = $Stats
@onready var quest_label: Label = $Quest
@onready var skills_label: Label = $Skills
@onready var hotbar_label: Label = $Hotbar
@onready var inventory_label: Label = $Inventory
@onready var status_label: Label = $Status
@onready var fishing_label: Label = $FishingStatus
@onready var buffs_label: Label = $Buffs
@onready var info_label: Label = $Info

var _status_seconds := 0.0

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
	GameEvents.toast_requested.connect(_show_status)
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)
	InputPrompts.input_method_changed.connect(_on_input_method_changed)
	GameSettings.controls_changed.connect(_refresh_controls_hint)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh_all()
	_refresh_fishing()

func _process(delta: float) -> void:
	if _status_seconds <= 0.0:
		return
	_status_seconds -= delta
	if _status_seconds <= 0.0:
		status_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_advance_time"):
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

func _on_quest_progress(_quest_id: StringName, _progress: int, _required: int) -> void:
	_refresh_quest()

func _on_skill_changed(_skill: StringName, _xp: int, _level: int) -> void:
	_refresh_skills()

func _on_fishing_state_changed(_state: FishingService.CastState, _message: String) -> void:
	_refresh_fishing()

func _on_save_completed(success: bool, message: String) -> void:
	_show_status(message if success else tr("Save failed: %s") % message)

func _on_load_completed(success: bool, message: String) -> void:
	_show_status(message if success else tr("Load failed: %s") % message)
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
	var location := ContentDB.get_current_location(get_tree())
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
	if info_label != null:
		info_label.text = InputPrompts.get_controls_summary()

func _refresh_fishing() -> void:
	fishing_label.text = FishingState.get_status_text()
	fishing_label.visible = not fishing_label.text.is_empty()

func _show_status(message: String) -> void:
	status_label.text = message
	_status_seconds = 2.5
