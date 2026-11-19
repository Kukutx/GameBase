class_name DialogueSpot
extends Node2D

## Something in the world that talks when the player uses it: a sign, a
## camp's keeper, a scout with a report. With the `Interactable` child the spot
## needs, interact shows `dialogue` from `dialogue_title` on
## (`Dialogue.show_dialogue()`), its lines reading the player and the spot. A
## game draws the spot itself, as children of its instance of
## `dialogue_spot.tscn`.

@export var dialogue: DialogueResource
@export var dialogue_title := "start"

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(actor: Node) -> void:
	Dialogue.show_dialogue(dialogue, dialogue_title, [actor, self])

## The spot needs a dialogue with its title; the registry adds the location it
## stands in to each problem.
func find_scene_problems(_registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	if DialogueService.has_title(dialogue, dialogue_title):
		return PackedStringArray()
	return PackedStringArray(["dialogue spot '%s' shows no dialogue under '%s'" % [name, dialogue_title]])
