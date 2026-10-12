class_name DepthEntrance
extends Node2D

## The way down from camp: starts a new run (`DepthRun.start_run()`) and takes
## the player to its first depth.

## The location of the depths and the spawn point a run starts at.
@export var depths_location_id: StringName
@export var arrival_spawn_id: StringName

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_actor: Node) -> void:
	if not WorldTravel.can_travel_to(depths_location_id, arrival_spawn_id):
		return
	DepthRun.start_run()
	WorldTravel.travel_to(depths_location_id, arrival_spawn_id)

func find_scene_problems(registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	if registry.has_location_spawn(depths_location_id, arrival_spawn_id):
		return PackedStringArray()
	return PackedStringArray(["depth entrance '%s' leads to spawn '%s' of '%s', which does not exist" % [name, arrival_spawn_id, depths_location_id]])
