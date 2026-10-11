extends GutTest

func after_each() -> void:
	get_tree().paused = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()

func _instantiate(path: String) -> Node:
	var scene := load(path) as PackedScene
	assert_not_null(scene, "Expected menu scene: %s" % path)
	if scene == null:
		return null
	var node := scene.instantiate()
	add_child_autofree(node)
	await get_tree().process_frame
	return node

func _assert_valid_focus(owner: Node) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	assert_not_null(focus, "%s opened without UI focus" % owner.name)
	if focus == null:
		return
	assert_true(owner == focus or owner.is_ancestor_of(focus), "%s focus escaped menu to %s" % [owner.name, focus.name])
	if focus is BaseButton:
		assert_false((focus as BaseButton).disabled, "%s focused a disabled button" % owner.name)

func test_game_menu_keeps_selected_tab_focusable() -> void:
	var menu := await _instantiate("res://game/ui/game_menu.tscn") as GameMenu
	assert_not_null(menu)
	if menu == null:
		return
	menu.open()
	await get_tree().process_frame
	var inventory := menu.get_node("Panel/Layout/Tabs/Inventory") as Button
	assert_false(inventory.disabled)
	assert_true(inventory.toggle_mode)
	assert_true(inventory.button_pressed)
	assert_eq(get_viewport().gui_get_focus_owner(), inventory)

	menu.call("_show_tab", "quests")
	await get_tree().process_frame
	var quests := menu.get_node("Panel/Layout/Tabs/Quests") as Button
	assert_false(quests.disabled)
	assert_true(quests.button_pressed)
	assert_false(inventory.button_pressed)
	assert_eq(get_viewport().gui_get_focus_owner(), quests)
	menu.close()

func test_overlay_menus_open_with_a_valid_focus_target() -> void:
	var cases: Array[Dictionary] = [
		{"path": "res://gamebase/modules/lifesim/animals/animal_management_menu.tscn", "kind": "animal"},
		{"path": "res://gamebase/modules/progression/contracts/daily_contract_menu.tscn", "kind": "contract"},
		{"path": "res://gamebase/modules/items/crafting/crafting_menu.tscn", "kind": "crafting"},
		{"path": "res://gamebase/modules/items/shop/shop_menu.tscn", "kind": "shop"},
		{"path": "res://gamebase/modules/items/storage/storage_menu.tscn", "kind": "storage"},
		{"path": "res://gamebase/modules/progression/projects/town_project_menu.tscn", "kind": "projects"},
		{"path": "res://gamebase/modules/progression/upgrades/tool_upgrade_menu.tscn", "kind": "upgrade"},
		{"path": "res://game/ui/settings_menu.tscn", "kind": "settings"},
		{"path": "res://game/ui/pause_menu.tscn", "kind": "pause"},
	]
	for data: Dictionary in cases:
		var menu := await _instantiate(String(data["path"]))
		assert_not_null(menu)
		if menu == null:
			continue
		match String(data["kind"]):
			"animal":
				menu.call("open", &"starter_town")
			"contract":
				menu.call("open")
			"crafting":
				menu.call("open")
			"shop":
				menu.call("open", ContentDB.get_shop(&"general_store"))
			"storage":
				menu.call("open", &"focus_test_chest", "Storage Chest", 24)
			"projects":
				menu.call("open", &"starter_town")
			"upgrade":
				menu.call("open")
			"settings":
				menu.call("open")
			"pause":
				menu.call("open")
		await get_tree().process_frame
		_assert_valid_focus(menu)
		if menu.has_method("close"):
			menu.call("close")
		await get_tree().process_frame

func test_ui_navigation_actions_include_gamepad_bindings() -> void:
	assert_true(_has_joy_button(&"ui_accept", JOY_BUTTON_A))
	assert_true(_has_joy_button(&"ui_cancel", JOY_BUTTON_B))
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		assert_true(_has_joy_navigation(action), "%s has no joypad navigation binding" % action)

func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false

func _has_joy_navigation(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false
