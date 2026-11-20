class_name DepthLine
extends PlaceLine

## Where the delver is and how deep: the depth of the floor they stand on
## (the floor's `get_place_detail()`), or at camp the deepest one they reached.

func _watch() -> void:
	super()
	watch(DepthRun.depth_reached)

func _get_parts() -> PackedStringArray:
	var parts := super()
	if not get_tree().current_scene is DepthFloor:
		parts.append(tr("Deepest %d") % DepthRun.get_deepest())
	return parts
