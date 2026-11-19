class_name MFarmWorldItem
extends Node2D

## An item lying in the world: one the scene placed (an item, a weed) or one
## dropped on the land (`Farmland.get_dropped()`, `dropped_id`). The player picks
## it up by walking over it, when it can be picked up and their bag has room.
## Weeds (`REAPABLE_SCENERY`) stay until a sickle reaps them.

const BOUNCE_SECONDS := 0.45
const BOUNCE_HEIGHT := 18.0

@export var item_id: StringName
## The id of the dropped item it shows, or -1 for an item the scene placed.
var dropped_id := -1

var _location_id := &""
var _sprite: Sprite2D
var _taken := false

func _ready() -> void:
	_location_id = MFarmLocation.id_of(self)
	if dropped_id < 0 and Farmland.is_taken(_location_id, MFarmLocation.key_of(self)):
		queue_free()
		return
	var item := MFarmItemData.find(item_id)
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	if item != null and _sprite.texture == null:
		MFarmSpritePivot.apply(_sprite, item.get_world_texture())
	if item != null and item.item_type == MFarmItemData.ItemType.REAPABLE_SCENERY:
		add_to_group(&"mfarm_reapable")
	for child: Node in get_children():
		if child is Area2D:
			var area := child as Area2D
			area.collision_mask = 2
			area.body_entered.connect(_on_body_entered)

func get_item() -> MFarmItemData:
	return MFarmItemData.find(item_id)

## Flies from `from` to where it lies, in an arc, as a harvest throws it.
func bounce_from(from: Vector2) -> void:
	var target := global_position
	global_position = from
	var tween := create_tween()
	tween.tween_property(self, ^"global_position", target, BOUNCE_SECONDS)
	tween.parallel().tween_method(_lift, 0.0, 1.0, BOUNCE_SECONDS)

func _lift(progress: float) -> void:
	if _sprite != null:
		var pivot: Vector2 = _sprite.texture.get_meta(&"pivot", Vector2.ZERO) if _sprite.texture != null else Vector2.ZERO
		_sprite.offset = -pivot - Vector2(0, sin(progress * PI) * BOUNCE_HEIGHT)

## Takes it out of the world for good: the land forgets it.
func remove() -> void:
	if _taken:
		return
	_taken = true
	if dropped_id >= 0:
		Farmland.remove_dropped(_location_id, dropped_id)
	else:
		Farmland.mark_taken(_location_id, MFarmLocation.key_of(self))
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	var item := get_item()
	if _taken or item == null or not item.can_pick_up or item.item_type == MFarmItemData.ItemType.REAPABLE_SCENERY:
		return
	if not body.is_in_group(&"player"):
		return
	if Bags.add_item(Bags.PLAYER, item_id, 1) == 0:
		GameEvents.toast("Your bag is full")
		return
	GameAudio.play_cue(&"sfx_pickup")
	remove()
