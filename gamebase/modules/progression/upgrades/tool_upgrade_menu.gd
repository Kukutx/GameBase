class_name ToolUpgradeMenu
extends MenuLayer

@onready var money_label: Label = $Panel/VBox/Money
@onready var items_container: VBoxContainer = $Panel/VBox/Scroll/Items
@onready var close_button: Button = $Panel/VBox/Close

func _init() -> void:
	super(&"tool_upgrade_menu")

func _ready() -> void:
	close_button.pressed.connect(close)
	InventoryState.changed.connect(_refresh_if_open)
	PlayerState.money_changed.connect(_on_money_changed)
	Skills.skill_xp_changed.connect(_on_skill_changed)
	UpgradeState.tool_upgraded.connect(_on_tool_upgraded)
	GameSettings.locale_changed.connect(_on_locale_changed)

func open() -> void:
	show_menu()
	_rebuild()

func _rebuild() -> void:
	for child: Node in items_container.get_children():
		child.queue_free()
	money_label.text = tr("Money: %dg") % PlayerState.money
	var first_button: Button
	for upgrade: ToolUpgradeData in UpgradeState.get_all_upgrades():
		if upgrade == null:
			continue
		var button := Button.new()
		button.text = "%s — %s" % [tr(upgrade.display_name), UpgradeState.get_requirement_text(upgrade)]
		button.disabled = not UpgradeState.can_upgrade(upgrade)
		button.pressed.connect(_upgrade.bind(upgrade.id))
		items_container.add_child(button)
		if first_button == null and not button.disabled:
			first_button = button
	if first_button != null:
		first_button.grab_focus()
	else:
		close_button.grab_focus()

func _upgrade(upgrade_id: StringName) -> void:
	UpgradeState.upgrade(upgrade_id)
	_rebuild()

func _refresh_if_open() -> void:
	if visible:
		_rebuild()

func _on_locale_changed(_locale: String) -> void:
	_refresh_if_open()

func _on_money_changed(_amount: int) -> void:
	_refresh_if_open()

func _on_skill_changed(_skill: StringName, _xp: int, _level: int) -> void:
	_refresh_if_open()

func _on_tool_upgraded(_upgrade_id: StringName, _source: StringName, _result: StringName) -> void:
	_refresh_if_open()
