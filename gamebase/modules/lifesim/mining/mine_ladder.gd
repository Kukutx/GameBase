class_name MineLadder
extends Node2D

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

var unlocked := false

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	set_unlocked(false)

func set_unlocked(value: bool) -> void:
	unlocked = value and MineState.get_current_floor() < MineRunState.MAX_FLOOR
	if interactable == null or label == null:
		return
	var next_floor := mini(MineState.get_current_floor() + 1, MineRunState.MAX_FLOOR)
	interactable.enabled = unlocked
	if unlocked:
		interactable.set_prompt("Descend to Floor %d", [next_floor])
	elif MineState.get_current_floor() >= MineRunState.MAX_FLOOR:
		interactable.set_prompt("Deepest floor reached")
	else:
		interactable.set_prompt("Clear the floor first")
	label.text = tr("Ladder ↓ F%d") % next_floor if unlocked else (tr("Ladder · bottom") if MineState.get_current_floor() >= MineRunState.MAX_FLOOR else tr("Ladder locked"))
	modulate.a = 1.0 if unlocked else 0.55

func _on_interacted(_actor: Node) -> void:
	if not unlocked:
		return
	var next_floor := mini(MineState.get_current_floor() + 1, MineRunState.MAX_FLOOR)
	if not WorldTravel.travel_to(&"old_mine", &"floor_entry"):
		GameEvents.toast("Could not descend right now")
		return
	MineState.set_floor(next_floor)
	GameEvents.toastf("Descending to Mine Floor %d", [next_floor])
