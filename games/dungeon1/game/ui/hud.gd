class_name DelverHud
extends CanvasLayer

## What the player of Ember Depths sees over the world: health, money and
## combat level, where the run stands, the hotbar, what is near to use, the
## status messages (toasts, hints and what a save or a load says, one after
## another on a `StatusLine`) and the controls. It holds the shop and pause
## menus.

@onready var stats_label: Label = $Stats
@onready var run_label: Label = $Run
@onready var hotbar_label: Label = $Hotbar
@onready var status_label: StatusLine = $Status
@onready var controls_label: Label = $Controls

func _ready() -> void:
	Vitals.changed.connect(_on_player_changed)
	Wallet.money_changed.connect(_on_player_changed)
	Skills.skill_xp_changed.connect(_on_player_changed)
	Hotbar.changed.connect(_refresh_hotbar)
	Hotbar.selected_slot_changed.connect(_on_hotbar_selected)
	InventoryState.changed.connect(_refresh_hotbar)
	DepthRun.depth_reached.connect(_on_depth_reached)
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)
	InputPrompts.input_method_changed.connect(_on_input_method_changed)
	GameSettings.controls_changed.connect(_refresh_controls)
	GameSettings.locale_changed.connect(_on_locale_changed)
	# The run line reads the current scene, which is set once the scene is in.
	_refresh_all.call_deferred()

## Shows `message` for a few seconds, after the messages before it.
func show_status(message: String) -> void:
	status_label.show_message(message)

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_run()
	_refresh_hotbar()
	_refresh_controls()

func _refresh_stats() -> void:
	var parts := Vitals.describe_all()
	parts.append(Wallet.describe())
	parts.append(tr("Combat Lv %d") % Skills.get_level(&"combat"))
	stats_label.text = " · ".join(parts)

func _refresh_run() -> void:
	var location := WorldLocationData.find_current(get_tree())
	var place := tr(location.display_name) if location != null else ""
	if get_tree().current_scene is DepthFloor:
		run_label.text = tr("%s · Depth %d") % [place, DepthRun.get_depth()]
	else:
		run_label.text = tr("%s · Deepest %d") % [place, DepthRun.get_deepest()]

func _refresh_hotbar() -> void:
	hotbar_label.text = Hotbar.get_text()

func _refresh_controls() -> void:
	controls_label.text = tr("%s move · %s attack · %s potion · %s use · %s next item") % [
		InputPrompts.get_move_prompt(),
		InputPrompts.get_action_prompt(&"attack"),
		InputPrompts.get_action_prompt(&"drink_potion"),
		InputPrompts.get_action_prompt(&"interact"),
		InputPrompts.get_action_prompt(&"next_item"),
	]

func _on_player_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_refresh_stats()

func _on_hotbar_selected(_index: int, _item_id: StringName) -> void:
	_refresh_hotbar()

func _on_depth_reached(_depth: int) -> void:
	_refresh_run()

func _on_save_completed(_success: bool, message: String) -> void:
	show_status(message)

func _on_load_completed(_success: bool, message: String) -> void:
	show_status(message)

func _on_input_method_changed(_using_gamepad: bool) -> void:
	_refresh_controls()

func _on_locale_changed(_locale: String) -> void:
	_refresh_all()
