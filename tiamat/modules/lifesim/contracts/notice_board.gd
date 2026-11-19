class_name TownNoticeBoard
extends Node2D

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	DailyContractState.contract_changed.connect(_on_contract_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("daily_contract_menu") as DailyContractMenu
	if menu == null:
		GameEvents.toast("Notice board UI is unavailable")
		return
	menu.open()

func _on_contract_changed(_contract: Dictionary) -> void:
	_refresh()

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _refresh() -> void:
	if label == null or interactable == null:
		return
	var state := DailyContractState.get_contract()
	if state.is_empty():
		label.text = tr("Notice Board")
		interactable.set_prompt("Check notice board")
		return
	if bool(state.get("claimed", false)):
		label.text = tr("Notice Board\nDone today")
	elif bool(state.get("completed", false)):
		label.text = tr("Notice Board\nReward ready")
	elif bool(state.get("accepted", false)):
		label.text = tr("Notice Board\n%d/%d") % [int(state.get("progress", 0)), int(state.get("required", 1))]
	else:
		label.text = tr("Notice Board\nNew request")
	interactable.set_prompt("Read notice board")
