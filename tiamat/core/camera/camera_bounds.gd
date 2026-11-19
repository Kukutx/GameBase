class_name CameraBounds
extends ReferenceRect

## The part of a location the view keeps inside: the game cameras
## (`GameCamera`) in the location show nothing beyond its edges. A location
## puts one in its scene, beside the player, and sizes it over its map; like
## any `ReferenceRect` it draws in the editor only, and it takes no mouse
## input.

## A limit far enough that the view never reaches it, for a view without bounds.
const UNBOUNDED := 10000000

## The bounds that hold for `node`: those beside it or beside a node it is in
## (the location's, for the camera on its player); null for none.
static func find_for(node: Node) -> CameraBounds:
	var parent := node.get_parent()
	while parent != null:
		for child: Node in parent.get_children():
			if child is CameraBounds:
				return child as CameraBounds
		parent = parent.get_parent()
	return null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# The cameras in the location that are ready before the bounds take them now.
func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group(GameCamera.GROUP):
		if get_parent().is_ancestor_of(node):
			(node as GameCamera).use_bounds(self)

## The bounds in world coordinates.
func get_world_rect() -> Rect2:
	return get_global_rect()
