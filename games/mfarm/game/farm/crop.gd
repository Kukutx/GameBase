class_name MFarmCrop
extends Node2D

## A crop drawn on its cell by `MFarmFarmGrid`, from the scene of its stage: a
## sprout, a tree, a rock. It shows its stage's sprite and plays what the
## player's tools do to it: a tree shakes and falls.

var cell := Vector2i.ZERO
var crop: MFarmCropData
var stage := 0

func setup(crop_cell: Vector2i, data: MFarmCropData, stage_index: int) -> void:
	cell = crop_cell
	crop = data
	stage = stage_index
	var sprite := get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null and stage_index < data.stage_sprites.size():
		MFarmSpritePivot.apply(sprite, data.stage_sprites[stage_index])

## Plays a hit from the side `from_left` names: a tree shakes away from it.
func play_hit(from_left: bool) -> void:
	_play(&"RotateRight" if from_left else &"RotateLeft")

## Plays the fall of a tree away from the player; returns its length in
## seconds, 0 when it has none.
func play_fall(from_left: bool) -> float:
	return _play(&"FallingRight" if from_left else &"FallingLeft")

func _play(animation: StringName) -> float:
	for player: Node in find_children("*", "AnimationPlayer", true, false):
		var animation_player := player as AnimationPlayer
		if animation_player.has_animation(animation):
			animation_player.play(animation)
			return animation_player.get_animation(animation).length
	return 0.0
