class_name MFarmSpritePivot
extends RefCounted

## Draws a sprite the way Unity drew it: with the pivot the import stored on
## its texture (`metadata/pivot`, pixels from the top left) on the node.

static func apply(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.centered = false
	if texture == null:
		return
	var pivot: Vector2 = texture.get_meta(&"pivot", texture.get_size() * 0.5)
	sprite.offset = -pivot
