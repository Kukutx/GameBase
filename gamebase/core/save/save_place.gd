class_name SavePlace
extends RefCounted

## The core's `place` section of a save (`GameSaveManager.PLACE_SECTION`):
## where the game was. It names the location, and where the player stood in
## it when a player walks the world:
##
##     {"location_id": "starter_town", "player": {"x": 48.0, "y": 32.0}}
##
## A game with no one walking its world (cards, a visual novel) keeps its
## location alone. The save manager opens the location last on a load, so
## reading the section restores nothing itself. Its functions are static: the
## section belongs to no save manager instance.

## Where the running game is now.
static func write() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var location := WorldLocationData.find_current(tree)
	var place := {"location_id": String(location.id) if location != null else ""}
	var player := tree.get_first_node_in_group("player") as Node2D
	if player != null:
		place["player"] = {"x": player.global_position.x, "y": player.global_position.y}
	return place

## Reads the section: nothing to restore before the location opens.
static func read(_section: Dictionary, _snapshot: Dictionary) -> void:
	pass

## The location of the place `snapshot` saved, or null.
static func find_location(snapshot: Dictionary) -> WorldLocationData:
	var place := _place_of(snapshot)
	return WorldLocationData.find(StringName(String(place.get("location_id", ""))))

## Where the player stood in the place `snapshot` saved, or null when no one
## did.
static func get_player_position(snapshot: Dictionary) -> Variant:
	var position: Variant = _place_of(snapshot).get("player")
	if not (position is Dictionary):
		return null
	var x: Variant = (position as Dictionary).get("x")
	var y: Variant = (position as Dictionary).get("y")
	if not (x is float or x is int) or not (y is float or y is int):
		return null
	return Vector2(float(x), float(y))

static func _place_of(snapshot: Dictionary) -> Dictionary:
	var place: Variant = snapshot.get(String(GameSaveManager.PLACE_SECTION))
	return place if place is Dictionary else {}
