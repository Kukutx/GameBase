class_name MineElevator
extends Node2D

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	MineState.deepest_floor_changed.connect(_on_deepest_changed)
	MineState.floor_changed.connect(_on_floor_changed)
	refresh()

func _on_interacted(_actor: Node) -> void:
	var current := MineState.get_current_floor()
	var target := 1 if current > 1 else MineState.get_deepest_checkpoint()
	if target == current or not MineState.can_use_elevator_floor(target):
		GameEvents.toast("No mine elevator checkpoint unlocked yet")
		return
	if not WorldTravel.travel_to(&"old_mine", &"floor_entry"):
		GameEvents.toast("Mine elevator is unavailable right now")
		return
	MineState.set_floor(target)
	GameEvents.toast("Mine elevator → Floor %d" % target)

func _on_deepest_changed(_floor: int) -> void:
	refresh()

func _on_floor_changed(_floor: int) -> void:
	refresh()

func refresh() -> void:
	if interactable == null or label == null:
		return
	var current := MineState.get_current_floor()
	if current > 1:
		interactable.enabled = true
		interactable.prompt_text = "Elevator to Floor 1"
		label.text = "Elevator ↑ F1"
		return
	var checkpoint := MineState.get_deepest_checkpoint()
	interactable.enabled = checkpoint >= MineRunState.CHECKPOINT_STEP
	interactable.prompt_text = "Elevator to Floor %d" % checkpoint if interactable.enabled else "Elevator checkpoint locked"
	label.text = "Elevator → F%d" % checkpoint if interactable.enabled else "Elevator locked"
