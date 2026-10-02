class_name MiningNodeData
extends Resource

@export var id: StringName
@export var display_name: String = "Rock"
@export_range(1, 999, 1) var durability := 3
@export_range(1, 120, 1) var minimum_mine_floor := 1
@export_range(1, 20, 1) var required_tool_power := 1
@export_range(0, 100, 1) var energy_cost := 3
@export var drop_item_id: StringName
@export_range(1, 99, 1) var drop_quantity := 1
@export_range(1, 28, 1) var respawn_days := 1
@export var visual_color := Color(0.48, 0.48, 0.50, 1.0)
