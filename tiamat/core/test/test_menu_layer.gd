extends GutTest

## The menu every core and module menu extends (`MenuLayer`): hidden until it
## shows, it pauses the world and holds the controls while shown, tells its
## opening and closing (`GameEvents`), and `ui_cancel` closes it. Its lists
## draw their entries' icons.

class FixtureMenu:
	extends MenuLayer

	func _init() -> void:
		super(&"fixture_menu")

func test_a_menu_holds_the_controls_while_it_shows() -> void:
	var menu := FixtureMenu.new()
	add_child_autofree(menu)
	assert_false(menu.visible)
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(get_tree().get_first_node_in_group(&"fixture_menu"), menu)
	watch_signals(menu)
	watch_signals(GameEvents)
	menu.show_menu()
	menu.show_menu()
	assert_signal_emit_count(GameEvents, "menu_opened", 1, "a menu that shows already opens no more")
	assert_signal_emitted_with_parameters(GameEvents, "menu_opened", [&"fixture_menu"])
	assert_true(menu.is_open())
	assert_true(InputLock.is_locked())
	assert_true(get_tree().paused)
	menu.close()
	assert_false(menu.is_open())
	assert_false(InputLock.is_locked())
	assert_false(get_tree().paused)
	assert_signal_emit_count(menu, "closed", 1)
	assert_signal_emitted_with_parameters(GameEvents, "menu_closed", [&"fixture_menu"])
	menu.close()
	assert_signal_emit_count(menu, "closed", 1, "a closed menu does not close again")
	assert_signal_emit_count(GameEvents, "menu_closed", 1)

func test_cancel_closes_the_menu_and_leaving_the_tree_gives_the_controls_back() -> void:
	var menu := FixtureMenu.new()
	add_child(menu)
	menu.show_menu()
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._unhandled_input(cancel)
	assert_false(menu.is_open())
	menu.show_menu()
	menu.free()
	assert_false(InputLock.is_locked(), "a freed menu holds nothing")
	assert_false(get_tree().paused)

func test_a_list_draws_each_rows_icon_and_shrinks_one_too_large() -> void:
	var small := _texture(16)
	var list := ItemList.new()
	autofree(list)
	var rows: Array[Dictionary] = [{"text": "Small", "key": &"fixture_small", "icon": small}, {"text": "Bare", "key": &"fixture_bare"}]
	MenuLayer.refill_list(list, rows)
	assert_eq(list.get_item_icon(0), small)
	assert_null(list.get_item_icon(1), "a row without an icon draws none")
	assert_eq(list.fixed_icon_size, Vector2i.ZERO, "an icon that fits keeps its size")
	var large: Array[Dictionary] = [{"text": "Large", "key": &"fixture_large", "icon": _texture(64)}]
	MenuLayer.refill_list(list, large)
	assert_eq(list.fixed_icon_size, Vector2i(MenuLayer.LIST_ICON_SIZE, MenuLayer.LIST_ICON_SIZE), "a larger one draws at the list's size")
	var fixed := ItemList.new()
	autofree(fixed)
	fixed.fixed_icon_size = Vector2i(40, 40)
	MenuLayer.refill_list(fixed, large)
	assert_eq(fixed.fixed_icon_size, Vector2i(40, 40), "a list with an icon size of its own keeps it")
	var button := MenuLayer.list_button("Buy Small", small)
	autofree(button)
	assert_eq([button.text, button.icon], ["Buy Small", small])
	assert_eq(button.get_theme_constant(&"icon_max_width"), MenuLayer.LIST_ICON_SIZE)

static func _texture(side: int) -> Texture2D:
	var texture := GradientTexture2D.new()
	texture.width = side
	texture.height = side
	return texture
