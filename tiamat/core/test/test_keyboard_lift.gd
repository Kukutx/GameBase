extends GutTest

## A phone's keyboard lifts the menu of the field typed in (`KeyboardLift`):
## the field shows just above it, never higher than the window's top, and the
## menu goes back down when the keyboard goes or the field lets go.

func test_a_menu_rises_over_a_phone_keyboard_while_its_field_is_typed_in() -> void:
	var lift := KeyboardLift.new()
	var menu := CanvasLayer.new()
	menu.offset = Vector2(0.0, 3.0)
	add_child_autofree(menu)
	var view := get_viewport().get_visible_rect().size
	var field := LineEdit.new()
	field.position = Vector2(10.0, view.y - 30.0)
	field.size = Vector2(100.0, 16.0)
	menu.add_child(field)
	var button := Button.new()
	menu.add_child(button)
	var root := get_tree().root
	var keyboard := root.size.y / 2
	lift.lift(get_viewport(), keyboard)
	assert_eq(menu.offset, Vector2(0.0, 3.0), "nothing typed in, nothing rises")
	field.grab_focus()
	lift.lift(get_viewport(), keyboard)
	assert_lt(menu.offset.y, 0.0)
	var shown := root.get_final_transform() * (menu.get_final_transform() * field.get_global_rect())
	assert_almost_eq(shown.end.y, float(root.size.y - keyboard) - KeyboardLift.GAP, 0.5, "the field shows just above the keyboard")
	lift.lift(get_viewport(), keyboard)
	assert_almost_eq((root.get_final_transform() * (menu.get_final_transform() * field.get_global_rect())).end.y, shown.end.y, 0.5, "and stays there")
	lift.lift(get_viewport(), 0)
	assert_eq(menu.offset, Vector2(0.0, 3.0), "the keyboard gone, the menu goes back down")
	field.position.y = 4.0
	lift.lift(get_viewport(), keyboard)
	assert_eq(menu.offset, Vector2(0.0, 3.0), "a field above the keyboard stays where it is")
	field.position.y = view.y - 30.0
	lift.lift(get_viewport(), root.size.y - 2)
	assert_almost_eq((root.get_final_transform() * (menu.get_final_transform() * field.get_global_rect())).position.y, 0.0, 0.5, "never higher than the top of the window")
	button.grab_focus()
	lift.lift(get_viewport(), keyboard)
	assert_eq(menu.offset, Vector2(0.0, 3.0), "the field let go, the menu goes back down")
	assert_eq(KeyboardLift.keyboard_height(), 0, "a computer has no keyboard on its screen")
