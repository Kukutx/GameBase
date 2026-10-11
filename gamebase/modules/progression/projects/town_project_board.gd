class_name TownProjectBoard
extends Node2D

@export var location_id: StringName

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	if location_id == &"":
		var location := WorldLocationData.find_current(get_tree())
		if location != null:
			location_id = location.id
	interactable.interacted.connect(_on_interacted)
	TownProjects.project_changed.connect(_on_project_changed)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("town_project_menu") as TownProjectMenu
	if menu == null:
		GameEvents.toast("Town project UI is unavailable")
		return
	menu.open(location_id)

func _on_project_changed(_project_id: StringName, _state: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	if label == null or interactable == null:
		return
	var projects := TownProjects.get_projects_for_location(location_id)
	if projects.is_empty():
		label.text = tr("Town Projects")
		interactable.prompt_text = "Check town projects"
		return
	var any_reward := false
	var all_claimed := true
	for project: TownProjectData in projects:
		if TownProjects.is_completed(project.id) and not TownProjects.is_claimed(project.id):
			any_reward = true
		if not TownProjects.is_claimed(project.id):
			all_claimed = false
	if any_reward:
		label.text = tr("Town Projects\nReward ready")
	elif all_claimed:
		label.text = tr("Town Projects\nRestored")
	else:
		label.text = tr("Town Projects\nNeeds help")
	interactable.prompt_text = "Review town projects"

func find_scene_problems(_registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	if location != null and location_id != &"" and location_id != location.id:
		return PackedStringArray(["town project board '%s' references different location '%s'" % [name, location_id]])
	return PackedStringArray()
