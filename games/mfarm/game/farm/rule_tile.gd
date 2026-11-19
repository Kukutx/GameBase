class_name MFarmRuleTile
extends Resource

## A tile that looks the way its four neighbours make it, like Unity's rule
## tiles: `textures[mask]`, where the mask has 1 for a neighbour of the same
## tile above, 2 to the right, 4 below and 8 to the left.

const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8

@export var textures: Array[Texture2D] = []

func texture_for(mask: int) -> Texture2D:
	return textures[mask] if mask >= 0 and mask < textures.size() else null

## The mask of `cell` among `cells` (cell -> anything).
static func mask_of(cell: Vector2i, cells: Dictionary) -> int:
	var mask := 0
	if cells.has(cell + Vector2i.UP):
		mask |= UP
	if cells.has(cell + Vector2i.RIGHT):
		mask |= RIGHT
	if cells.has(cell + Vector2i.DOWN):
		mask |= DOWN
	if cells.has(cell + Vector2i.LEFT):
		mask |= LEFT
	return mask
