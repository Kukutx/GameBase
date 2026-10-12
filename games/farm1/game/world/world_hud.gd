class_name WorldHud
extends CanvasLayer

## What the farmer sees over the world. The clock, the hotbar, the controls and
## the status messages are lines of their own (`FarmClockLine`, `HotbarLine`,
## `ControlsLine`, `StatusLine`); this tells the vitals and money, the quest,
## the skills, the inventory, the buffs and the fishing cast.

@onready var stats_label: Label = $Stats
@onready var quest_label: Label = $Quest
@onready var skills_label: Label = $Skills
@onready var inventory_label: Label = $Inventory
@onready var status_label: StatusLine = $Status
@onready var fishing_label: Label = $FishingStatus
@onready var buffs_label: Label = $Buffs

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_time_changed)
	InventoryState.changed.connect(_refresh_inventory)
	Vitals.changed.connect(_on_vital_changed)
	Wallet.money_changed.connect(_on_money_changed)
	QuestState.quest_started.connect(_on_quest_event)
	QuestState.quest_progressed.connect(_on_quest_progress)
	QuestState.quest_completed.connect(_on_quest_event)
	Skills.skill_xp_changed.connect(_on_skill_changed)
	BuffState.buffs_changed.connect(_refresh_buffs)
	FishingState.cast_state_changed.connect(_on_fishing_state_changed)
	SaveManager.load_completed.connect(_on_load_completed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	# A development shortcut: exported release builds never skip time.
	if OS.is_debug_build() and event.is_action_pressed("debug_advance_time"):
		WorldClock.advance_minutes(60)
		status_label.show_message(tr("Advanced time by 1 hour"))
		get_viewport().set_input_as_handled()

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_quest()
	_refresh_skills()
	_refresh_inventory()
	_refresh_buffs()
	_refresh_fishing()

func _on_time_changed(_day: int, _minute_of_day: int) -> void:
	_refresh_buffs()

func _on_vital_changed(_vital_id: StringName, _current: int, _maximum: int) -> void:
	_refresh_stats()

func _on_money_changed(_amount: int) -> void:
	_refresh_stats()

func _on_quest_event(_quest_id: StringName) -> void:
	_refresh_quest()

func _on_quest_progress(_quest_id: StringName, _objective: int, _progress: int, _required: int) -> void:
	_refresh_quest()

func _on_skill_changed(_skill: StringName, _xp: int, _level: int) -> void:
	_refresh_skills()

func _on_fishing_state_changed(_state: FishingService.CastState, _message: String) -> void:
	_refresh_fishing()

func _on_load_completed(success: bool, _message: String) -> void:
	if success:
		_refresh_all()

func _on_locale_changed(_locale: String) -> void:
	_refresh_all()

func _refresh_stats() -> void:
	var parts := Vitals.describe_all()
	parts.append(Wallet.describe())
	stats_label.text = "   ·   ".join(parts)

func _refresh_quest() -> void:
	quest_label.text = tr("Quest: %s") % QuestState.get_active_summary()

func _refresh_skills() -> void:
	skills_label.text = Skills.get_summary()

func _refresh_inventory() -> void:
	inventory_label.text = InventoryState.get_summary(6)

func _refresh_buffs() -> void:
	var summary := BuffState.get_summary()
	buffs_label.text = tr("Buffs: %s") % summary if not summary.is_empty() else ""
	buffs_label.visible = not buffs_label.text.is_empty()

func _refresh_fishing() -> void:
	fishing_label.text = FishingState.get_status_text()
	fishing_label.visible = not fishing_label.text.is_empty()
