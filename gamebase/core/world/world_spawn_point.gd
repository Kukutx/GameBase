class_name WorldSpawnPoint
extends Marker2D

## Where the player stands on arriving in a location by `spawn_id`: a travel
## or a load puts them here (`WorldTravel.place_player()`).

@export var spawn_id: StringName

## The spawn point `spawn_id` of the scene `tree` shows, or null.
static func find(tree: SceneTree, id: StringName) -> WorldSpawnPoint:
	for node: Node in tree.get_nodes_in_group("world_spawn_point"):
		var spawn := node as WorldSpawnPoint
		if spawn != null and spawn.spawn_id == id:
			return spawn
	return null

func _ready() -> void:
	add_to_group("world_spawn_point")
