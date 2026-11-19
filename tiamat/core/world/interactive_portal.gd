class_name InteractivePortal
extends Node2D

## A way to another location that the player takes on purpose: a door, a
## stair or a way down they use (with the `Interactable` child the portal
## needs) rather than walk into, as they walk into a `ScenePortal`.
## `about_to_travel` lets the game act first, such as starting a run on the
## way down.

## Emitted when the player takes the portal, before the travel starts.
signal about_to_travel

## Where the portal leads: a location and its spawn point (the location's
## default spawn point when empty).
@export var target_location_id: StringName
@export var target_spawn_id: StringName

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

## Takes the player through: true when the travel starts.
func take() -> bool:
	if not WorldTravel.can_travel_to(target_location_id, target_spawn_id):
		GameEvents.toast("That way is closed for now")
		return false
	about_to_travel.emit()
	return WorldTravel.travel_to(target_location_id, target_spawn_id)

func _on_interacted(_actor: Node) -> void:
	take()

## Where the portal leads must be a location of `registry` and one of its
## spawn points; the registry adds the location it stands in to each problem.
func find_scene_problems(registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	var target := registry.get_entry(WorldLocationData.KIND, target_location_id) as WorldLocationData
	if target == null:
		return PackedStringArray(["portal '%s' leads to unknown location '%s'" % [name, target_location_id]])
	var spawn := target_spawn_id if target_spawn_id != &"" else target.default_spawn_id
	if registry.has_location_spawn(target_location_id, spawn):
		return PackedStringArray()
	return PackedStringArray(["portal '%s' leads to spawn '%s' of '%s', which does not exist" % [name, spawn, target_location_id]])
