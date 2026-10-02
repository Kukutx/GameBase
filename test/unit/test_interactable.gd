extends GutTest

func test_interact_emits_when_enabled() -> void:
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	watch_signals(interactable)

	var actor := Node.new()
	add_child_autofree(actor)
	interactable.interact(actor)

	assert_signal_emitted_with_parameters(interactable, "interacted", [actor])

func test_interact_does_not_emit_when_disabled() -> void:
	var interactable := Interactable.new()
	add_child_autofree(interactable)
	interactable.enabled = false
	watch_signals(interactable)

	interactable.interact(null)

	assert_signal_not_emitted(interactable, "interacted")
