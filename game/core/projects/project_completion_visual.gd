class_name ProjectCompletionVisual
extends Node2D

@export var completion_flag: StringName
@export var pending_text := "Needs restoration"
@export var completed_text := "Restored"
@export var pending_color := Color(0.38, 0.30, 0.22, 1)
@export var completed_color := Color(0.28, 0.62, 0.34, 1)

@onready var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
@onready var label: Label = get_node_or_null("Label") as Label

func _ready() -> void:
	WorldState.changed.connect(_on_world_state_changed)
	_refresh()

func _on_world_state_changed(key: StringName, _value: Variant) -> void:
	if key == &"" or key == completion_flag:
		_refresh()

func _refresh() -> void:
	var completed := completion_flag != &"" and WorldState.get_bool(completion_flag)
	if visual != null:
		visual.color = completed_color if completed else pending_color
	if label != null:
		label.text = completed_text if completed else pending_text
