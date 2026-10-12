extends GutTest

## The menu every core and module menu extends (`MenuLayer`): hidden until it
## shows, it pauses the world and holds the controls while shown, tells its
## opening and closing (`GameEvents`), and `ui_cancel` closes it.

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
