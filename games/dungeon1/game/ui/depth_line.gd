class_name DepthLine
extends PlaceLine

## Where the delver is and how deep: the depth of the floor they stand on, or
## at camp the deepest one they reached.

func _watch() -> void:
	super()
	watch(DepthRun.depth_reached)

func _get_parts() -> PackedStringArray:
	var parts := super()
	if get_tree().current_scene is DepthFloor:
		parts.append(tr("Depth %d") % DepthRun.get_depth())
	else:
		parts.append(tr("Deepest %d") % DepthRun.get_deepest())
	return parts
