class_name MiniGameStation
extends Node2D

## Something in the world the player uses to play a minigame
## (`MiniGameDefinition`): a war table, an arcade cabinet, a card table. With
## the `Interactable` child the station needs, interact runs `minigame_id`
## through `MiniGameHost`, with `context` over the minigame's own settings, and
## `played` says how it went. A game draws the station itself, as children of
## its instance of `minigame_station.tscn`.

## The minigame ended, or could not start (`MiniGameHost.run()`).
signal played(result: MiniGameResult)

@export var minigame_id: StringName
## Settings over the minigame's own (`MiniGameDefinition.settings`).
@export var context: Dictionary = {}

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

## Runs the minigame and gives how it went.
func play() -> MiniGameResult:
	var result: MiniGameResult = await MiniGameHost.run(minigame_id, context)
	played.emit(result)
	return result

func _on_interacted(_actor: Node) -> void:
	play()

## The station's minigame must be one of `registry`; the registry adds the
## location it stands in to each problem.
func find_scene_problems(registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	if registry.has_entry(MiniGameDefinition.KIND, minigame_id):
		return PackedStringArray()
	return PackedStringArray(["station '%s' runs unknown minigame '%s'" % [name, minigame_id]])
