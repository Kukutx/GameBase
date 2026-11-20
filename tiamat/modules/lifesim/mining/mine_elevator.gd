class_name MineElevator
extends Node2D

## The mine's elevator: it takes the player to the floors it stops at, floor 1
## and every `MineRunState.CHECKPOINT_STEP`th floor down to the deepest the
## player reached (`MineState.get_elevator_floors()`). With one stop besides
## the floor the player is on, using it goes there; with more, it lists them
## (`ChoiceMenu`) for the player to pick, the focus on floor 1 below it and on
## the deepest stop at the top.

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

## The mine the elevator is in; its MineFloorController sets it.
var mine: MineFloorController

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	MineState.deepest_floor_changed.connect(_on_deepest_changed)
	MineState.floor_changed.connect(_on_floor_changed)
	refresh()

## The floors the elevator takes the player to from the one they are on, from
## the top down.
func get_stops() -> PackedInt32Array:
	var current := MineState.get_current_floor()
	var stops := PackedInt32Array()
	for floor: int in MineState.get_elevator_floors():
		if floor != current and MineState.can_use_elevator_floor(floor):
			stops.append(floor)
	return stops

## Takes the player to `floor`, one of the stops; true when the ride starts.
func ride_to(floor: int) -> bool:
	if not get_stops().has(floor):
		GameEvents.toast("No mine elevator checkpoint unlocked yet")
		return false
	if mine == null or not mine.travel_to_floor(floor):
		GameEvents.toast("Mine elevator is unavailable right now")
		return false
	GameEvents.toastf("Mine elevator → Floor %d", [floor])
	return true

## The list of stops the elevator shows, or null before it first showed it.
func get_choice_menu() -> ChoiceMenu:
	return ChoiceMenu.of(self)

func _on_interacted(_actor: Node) -> void:
	var stops := get_stops()
	if stops.is_empty():
		GameEvents.toast("No mine elevator checkpoint unlocked yet")
		return
	if stops.size() == 1:
		ride_to(stops[0])
		return
	var choices: Array[ChoiceMenu.Choice] = []
	for floor: int in stops:
		choices.append(ChoiceMenu.Choice.new(StringName(str(floor)), tr("Floor %d") % floor))
	var focus := 1 if MineState.get_current_floor() > 1 else stops[stops.size() - 1]
	var picked: StringName = await ChoiceMenu.ask(self, choices, "Mine Elevator", StringName(str(focus)))
	if picked != &"":
		ride_to(int(String(picked)))

func _on_deepest_changed(_floor: int) -> void:
	refresh()

func _on_floor_changed(_floor: int) -> void:
	refresh()

func refresh() -> void:
	if interactable == null or label == null:
		return
	var stops := get_stops()
	interactable.enabled = not stops.is_empty()
	if stops.is_empty():
		interactable.set_prompt("Elevator checkpoint locked")
		label.text = tr("Elevator locked")
	elif stops.size() > 1:
		interactable.set_prompt("Use elevator")
		label.text = tr("Mine Elevator")
	elif stops[0] == 1:
		interactable.set_prompt("Elevator to Floor 1")
		label.text = tr("Elevator ↑ F1")
	else:
		interactable.set_prompt("Elevator to Floor %d", [stops[0]])
		label.text = tr("Elevator → F%d") % stops[0]
