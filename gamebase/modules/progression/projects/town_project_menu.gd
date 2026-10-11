class_name TownProjectMenu
extends CanvasLayer

@onready var title_label: Label = $Panel/Layout/Title
@onready var projects_container: VBoxContainer = $Panel/Layout/Scroll/Projects
@onready var close_button: Button = $Panel/Layout/Close

var _location_id: StringName

func _ready() -> void:
	add_to_group("town_project_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	TownProjects.project_changed.connect(_on_project_changed)
	InventoryState.changed.connect(_refresh_if_visible)
	GameSettings.locale_changed.connect(_on_locale_changed)

func open(location_id: StringName) -> void:
	_location_id = location_id
	visible = true
	get_tree().paused = true
	_rebuild()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for child: Node in projects_container.get_children():
		child.queue_free()
	var location := ContentDB.get_location(_location_id)
	title_label.text = tr("%s Projects") % (tr(location.display_name) if location != null else tr("Town"))
	var projects := TownProjects.get_projects_for_location(_location_id)
	var first_button: Button
	if projects.is_empty():
		var empty := Label.new()
		empty.text = tr("No restoration projects are registered here yet.")
		projects_container.add_child(empty)
	for project: TownProjectData in projects:
		var block := VBoxContainer.new()
		var heading := Label.new()
		heading.text = tr(project.display_name)
		heading.add_theme_font_size_override("font_size", 14)
		block.add_child(heading)
		var body := RichTextLabel.new()
		body.fit_content = true
		body.custom_minimum_size = Vector2(0, 72)
		body.bbcode_enabled = true
		body.text = _project_text(project)
		block.add_child(body)
		var action := Button.new()
		_configure_action(action, project)
		block.add_child(action)
		projects_container.add_child(block)
		if first_button == null and not action.disabled:
			first_button = action
	if first_button != null:
		first_button.grab_focus()
	else:
		close_button.grab_focus()

func _project_text(project: TownProjectData) -> String:
	var lines := PackedStringArray([tr(project.description), "", "[b]%s[/b]" % tr("Materials")])
	for raw_id: Variant in project.requirements.keys():
		var item_id := StringName(String(raw_id))
		var item := ContentDB.get_item(item_id)
		var required := project.get_required_quantity(item_id)
		var progress := TownProjects.get_progress(project.id, item_id)
		var carried := InventoryState.get_quantity(item_id)
		lines.append(tr("• %s  %d/%d  (carrying %d)") % [tr(item.display_name) if item != null else String(item_id), progress, required, carried])
	lines.append("")
	lines.append("[b]%s[/b]" % tr("Reward"))
	if project.reward_money > 0:
		lines.append("• %dg" % project.reward_money)
	for raw_id: Variant in project.reward_items.keys():
		var item := ContentDB.get_item(StringName(String(raw_id)))
		lines.append("• %s x%d" % [tr(item.display_name) if item != null else String(raw_id), int(project.reward_items[raw_id])])
	if not project.prerequisites.is_empty() and not TownProjects.is_available(project.id):
		lines.append("")
		lines.append("[i]%s[/i]" % tr("Complete the earlier town project first."))
	return "\n".join(lines)

func _configure_action(button: Button, project: TownProjectData) -> void:
	if not TownProjects.is_available(project.id):
		button.text = tr("Locked")
		button.disabled = true
	elif TownProjects.is_claimed(project.id):
		button.text = tr("Completed")
		button.disabled = true
	elif TownProjects.is_completed(project.id):
		button.text = tr("Claim Reward")
		button.disabled = false
		button.pressed.connect(_claim.bind(project.id))
	else:
		button.text = tr("Donate Available Materials")
		button.disabled = not _has_any_donation(project)
		button.pressed.connect(_donate.bind(project.id))

func _has_any_donation(project: TownProjectData) -> bool:
	for raw_id: Variant in project.requirements.keys():
		var item_id := StringName(String(raw_id))
		if TownProjects.get_progress(project.id, item_id) < project.get_required_quantity(item_id) and InventoryState.has_item(item_id, 1):
			return true
	return false

func _donate(project_id: StringName) -> void:
	if TownProjects.contribute_all_available(project_id) <= 0:
		GameEvents.toast(tr("You are not carrying any needed materials"))
	_rebuild()

func _claim(project_id: StringName) -> void:
	TownProjects.claim_reward(project_id)
	_rebuild()

func _on_project_changed(_project_id: StringName, _state: Dictionary) -> void:
	_refresh_if_visible()

func _on_locale_changed(_locale: String) -> void:
	_refresh_if_visible()

func _refresh_if_visible() -> void:
	if visible:
		_rebuild()
