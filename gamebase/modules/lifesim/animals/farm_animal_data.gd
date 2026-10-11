class_name FarmAnimalData
extends Resource

@export var id: StringName
@export var display_name: String = "Animal"
@export var sprite_path: String
@export var frame_size := Vector2i(32, 32)
@export_range(1, 60, 1) var animation_fps := 10
@export_range(0, 999, 1) var idle_from := 0
@export_range(0, 999, 1) var idle_to := 0
@export_range(0, 999, 1) var walk_from := 0
@export_range(0, 999, 1) var walk_to := 0
@export_range(0, 999, 1) var eat_from := 0
@export_range(0, 999, 1) var eat_to := 0
@export_range(1.0, 300.0, 1.0) var move_speed := 28.0
@export_range(8.0, 256.0, 1.0) var wander_radius := 56.0
@export var collision_size := Vector2(14, 10)
@export var visual_offset := Vector2.ZERO
@export_range(0.1, 4.0, 0.05) var visual_scale := 1.0
@export_group("Ownership")
@export var housing_type: StringName = &"coop"
@export_range(0, 999999, 1) var purchase_price := 500
@export var feed_item_id: StringName = &"hay"
@export_range(0, 100, 1) var missed_feed_happiness_loss := 3

@export_group("Production")
@export var product_item_id: StringName
@export var premium_product_item_id: StringName
@export_range(0, 100, 1) var premium_happiness_threshold := 80
@export_range(1, 99, 1) var product_quantity := 1
@export_range(1, 28, 1) var product_interval_days := 1
@export_range(0, 100, 1) var pet_happiness_gain := 5

func has_valid_animation_ranges() -> bool:
	return idle_from <= idle_to and walk_from <= walk_to and eat_from <= eat_to

func get_product_item_id(happiness: int) -> StringName:
	if premium_product_item_id != &"" and happiness >= premium_happiness_threshold:
		return premium_product_item_id
	return product_item_id
