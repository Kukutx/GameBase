class_name DailyContractMenu
extends CanvasLayer

@onready var title_label: Label = $Panel/Layout/Title
@onready var body_label: RichTextLabel = $Panel/Layout/Body
@onready var action_button: Button = $Panel/Layout/Action
@onready var close_button: Button = $Panel/Layout/Close

func _ready() -> void:
	add_to_group("daily_contract_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	action_button.pressed.connect(_on_action)
	close_button.pressed.connect(close)
	DailyContractState.contract_changed.connect(_on_contract_changed)

func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh()
	action_button.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_action() -> void:
	var state := DailyContractState.get_contract()
	if state.is_empty():
		return
	if not bool(state.get("accepted", false)):
		DailyContractState.accept()
	elif bool(state.get("completed", false)) and not bool(state.get("claimed", false)):
		DailyContractState.claim()
	_refresh()

func _on_contract_changed(_contract: Dictionary) -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	var state := DailyContractState.get_contract()
	if state.is_empty():
		title_label.text = "Town Notice Board"
		body_label.text = "No notice available today."
		action_button.disabled = true
		action_button.text = "Unavailable"
		return
	title_label.text = String(state.get("title", "Town Contract"))
	var accepted := bool(state.get("accepted", false))
	var completed := bool(state.get("completed", false))
	var claimed := bool(state.get("claimed", false))
	var progress := int(state.get("progress", 0))
	var required := maxi(int(state.get("required", 1)), 1)
	body_label.text = "[b]%s[/b]\n\n%s\n\nProgress: %d/%d\nReward: %dg\nDeadline: Day %d" % [
		"Accepted" if accepted else "Available",
		String(state.get("description", "")),
		progress,
		required,
		int(state.get("reward_money", 0)),
		int(state.get("expires_day", WorldClock.day)),
	]
	if claimed:
		action_button.text = "Claimed"
		action_button.disabled = true
	elif completed:
		action_button.text = "Claim Reward"
		action_button.disabled = false
	elif accepted:
		action_button.text = "In Progress"
		action_button.disabled = true
	else:
		action_button.text = "Accept Contract"
		action_button.disabled = false
