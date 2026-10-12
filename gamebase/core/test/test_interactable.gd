extends GutTest

func test_interact_emits_when_enabled() -> void:
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	watch_signals(interactable)

	var actor := Node.new()
	add_child_autofree(actor)
	interactable.interact(actor)

	assert_signal_emitted_with_parameters(interactable, "interacted", [actor])

func test_prompt_template_translates_at_render_time() -> void:
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	var previous := TranslationServer.get_locale()
	interactable.set_prompt("Unknown location: %s", ["Spring"])

	TranslationServer.set_locale("zh_CN")
	assert_eq(interactable.get_prompt_text(), "未知地点：春季")

	TranslationServer.set_locale("en")
	assert_eq(interactable.get_prompt_text(), "Unknown location: Spring")
	TranslationServer.set_locale(previous)

func test_interact_does_not_emit_when_disabled() -> void:
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	interactable.enabled = false
	watch_signals(interactable)

	interactable.interact(null)

	assert_signal_not_emitted(interactable, "interacted")

func test_a_press_while_the_controls_are_locked_is_left_to_whoever_holds_them() -> void:
	var controller := InteractionController.new()
	add_child_autofree(controller)
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	controller.call("_on_area_entered", interactable)
	assert_eq(controller.get_focused(), interactable)
	watch_signals(interactable)
	var press := InputEventAction.new()
	press.action = controller.action
	press.pressed = true
	InputLock.lock(&"fixture_cast")
	Input.parse_input_event(press)
	await get_tree().process_frame
	InputLock.unlock(&"fixture_cast")
	assert_signal_not_emitted(interactable, "interacted", "a fishing cast reels in with the press")
	Input.parse_input_event(press)
	await get_tree().process_frame
	assert_signal_emitted(interactable, "interacted")
	var release := InputEventAction.new()
	release.action = controller.action
	Input.parse_input_event(release)

func test_a_disabled_interactable_in_reach_is_focused_once_it_is_enabled() -> void:
	var controller := InteractionController.new()
	add_child_autofree(controller)
	var interactable := Interactable.new()
	interactable.enabled = false
	add_child_autofree(interactable)
	controller.call("_on_area_entered", interactable)
	assert_null(controller.get_focused())
	interactable.enabled = true
	assert_eq(controller.get_focused(), interactable, "it stayed in reach while disabled")

func test_the_prompt_follows_what_the_focused_interactable_says() -> void:
	var controller := InteractionController.new()
	var label := Label.new()
	controller.prompt_label = label
	add_child_autofree(controller)
	add_child_autofree(label)
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	controller.call("_on_area_entered", interactable)
	assert_string_contains(label.text, "Interact")
	interactable.set_prompt("Harvest %s", ["Turnip"])
	assert_string_contains(label.text, "Harvest Turnip")
	interactable.prompt_text = "Rock"
	assert_string_contains(label.text, "Rock")

func test_the_prompt_hides_when_the_focus_is_disabled_or_freed() -> void:
	var controller := InteractionController.new()
	var label := Label.new()
	controller.prompt_label = label
	add_child_autofree(controller)
	add_child_autofree(label)
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	controller.call("_on_area_entered", interactable)
	assert_true(label.visible)
	interactable.enabled = false
	controller.get_focused()
	assert_false(label.visible, "a disabled interactable shows no prompt")
	interactable.enabled = true
	controller.get_focused()
	assert_true(label.visible)
	# Freed without the area noticing it leave.
	interactable.free()
	assert_null(controller.get_focused())
	assert_false(label.visible)
