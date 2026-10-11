class_name ProjectCompletionVisual
extends Node2D

## Shows whether a town project is completed: its colour and label switch
## when the town completes the project.

@export var project_id: StringName
@export var pending_text := "Needs restoration"
@export var completed_text := "Restored"
@export var pending_color := Color(0.38, 0.30, 0.22, 1)
@export var completed_color := Color(0.28, 0.62, 0.34, 1)

@onready var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
@onready var label: Label = get_node_or_null("Label") as Label

func _ready() -> void:
	WorldState.changed.connect(_on_world_state_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh()

func find_scene_problems(registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	if not registry.has_entry(TownProjectData.KIND, project_id):
		return PackedStringArray(["project completion visual '%s' references unknown town project '%s'" % [name, project_id]])
	return PackedStringArray()

# Town projects keep their state under one world key; an empty key means the
# whole store was replaced, by a load or a new game.
func _on_world_state_changed(key: StringName, _value: Variant) -> void:
	if key == TownProjectService.STATE_KEY or key == &"":
		_refresh()

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _refresh() -> void:
	var completed := TownProjects.is_completed(project_id)
	if visual != null:
		visual.color = completed_color if completed else pending_color
	if label != null:
		label.text = tr(completed_text) if completed else tr(pending_text)
