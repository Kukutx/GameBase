class_name EnemyData
extends ContentEntry

@export var display_name: String = "Enemy"
@export var sprite_path: String
@export var frame_size := Vector2i(32, 32)
@export_range(1, 60, 1) var animation_fps := 12
@export_range(0, 999, 1) var idle_from := 0
@export_range(0, 999, 1) var idle_to := 0
@export_range(0, 999, 1) var move_from := 0
@export_range(0, 999, 1) var move_to := 0
@export_range(0, 999, 1) var death_from := 0
@export_range(0, 999, 1) var death_to := 0
@export_range(1, 999, 1) var max_health := 30
@export_range(1.0, 300.0, 1.0) var move_speed := 36.0
@export_range(8.0, 400.0, 1.0) var chase_radius := 110.0
@export_range(4.0, 64.0, 1.0) var attack_range := 16.0
@export_range(0, 999, 1) var contact_damage := 8
@export_range(0.1, 10.0, 0.1) var attack_cooldown := 1.2
@export var collision_size := Vector2(16, 12)
@export var visual_offset := Vector2(0, -5)
@export_range(0.1, 4.0, 0.05) var visual_scale := 1.0
@export var drop_item_id: StringName
@export_range(0, 99, 1) var drop_quantity := 1
@export_range(1, 28, 1) var respawn_days := 1
@export_range(0, 9999, 1) var combat_xp := 20

func has_valid_animation_ranges() -> bool:
	return idle_from <= idle_to and move_from <= move_to and death_from <= death_to
