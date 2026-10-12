extends GutTest

## One conversation at a time (`DialogueService`): it holds the player's
## controls and pauses the world until its dialogue ends or its balloon goes,
## refuses a second one while it shows, and says when a dialogue file was read
## to its end. A spot in the world (`DialogueSpot`) shows its dialogue on use.

const DIALOGUE_TEXT := """~ start
Fixture: The road north is open.
=> END

~ other
Fixture: Nothing new.
=> END
"""

class FixtureChat extends DialogueChat:
	func get_line(id: String) -> DialogueLine:
		return DialogueChat.make_line("fixture", "Fixture", "Hello.", []) if id == FIRST else null

var _toasts: Array[String] = []

func before_each() -> void:
	_toasts.clear()
	GameEvents.toast_requested.connect(_on_toast)

func after_each() -> void:
	GameEvents.toast_requested.disconnect(_on_toast)
	InputLock.unlock(DialogueService.LOCK)

func test_a_dialogue_has_a_title_when_it_has_lines_under_it() -> void:
	var resource := _dialogue()
	assert_true(DialogueService.has_title(resource, "start"))
	assert_true(DialogueService.has_title(resource, ""), "from its first line")
	assert_false(DialogueService.has_title(resource, "missing"))
	assert_false(DialogueService.has_title(null, "start"))

func test_a_conversation_holds_the_controls_until_its_dialogue_ends_or_its_balloon_goes() -> void:
	var service := _service()
	var dialogue := _dialogue()
	var balloon := Node.new()
	add_child_autofree(balloon)
	service.call("_hold_controls", balloon, dialogue)
	assert_true(service.is_showing())
	assert_true(InputLock.is_held(DialogueService.LOCK))
	assert_true(get_tree().paused, "the world waits while the player reads")
	var ended: Array[DialogueResource] = []
	service.finished.connect(func(resource: DialogueResource) -> void: ended.append(resource))
	service.call("_on_dialogue_ended", _dialogue())
	assert_true(InputLock.is_held(DialogueService.LOCK), "another dialogue's end is not this one's")
	assert_eq(ended.size(), 0)
	service.call("_on_dialogue_ended", dialogue)
	assert_false(InputLock.is_held(DialogueService.LOCK), "its end gives the controls back")
	assert_false(get_tree().paused)
	assert_eq(ended, [dialogue] as Array[DialogueResource], "it was read to its end")

	var next_balloon := Node.new()
	add_child(next_balloon)
	service.call("_hold_controls", next_balloon, dialogue)
	assert_true(InputLock.is_held(DialogueService.LOCK))
	next_balloon.free()
	assert_false(InputLock.is_held(DialogueService.LOCK), "a balloon that goes before its dialogue ends gives them back too")
	assert_false(service.is_showing())
	service.call("_on_dialogue_ended", dialogue)
	assert_eq(ended.size(), 1, "a dialogue whose balloon went was not read to its end")

func test_one_conversation_shows_at_a_time() -> void:
	var service := _service()
	var balloon := service.show_dialogue(_dialogue(), "start")
	assert_not_null(balloon)
	assert_true(service.is_showing())
	assert_null(service.show_dialogue(_dialogue(), "other"), "a second one waits for the first")
	assert_null(service.show_chat(FixtureChat.new()))
	assert_eq(_toasts, ["Finish the current conversation first", "Finish the current conversation first"] as Array[String])
	balloon.free()
	assert_false(service.is_showing())
	assert_false(InputLock.is_held(DialogueService.LOCK))

func test_a_missing_title_shows_nothing() -> void:
	var service := _service()
	assert_null(service.show_dialogue(_dialogue(), "missing"))
	assert_false(service.is_showing())
	assert_false(InputLock.is_held(DialogueService.LOCK))

func test_a_chat_shows_its_lines_in_the_balloon() -> void:
	var service := _service()
	var balloon := service.show_chat(FixtureChat.new())
	assert_not_null(balloon)
	# GUT's own waits stop while the world is paused, as it is for a
	# conversation; the tree's frames go on.
	for _frame: int in 60:
		if balloon.get_line() != null:
			break
		await get_tree().process_frame
	assert_eq(balloon.get_line().text, "Hello.")
	assert_true(InputLock.is_held(DialogueService.LOCK))
	balloon.free()
	assert_false(InputLock.is_held(DialogueService.LOCK))

func test_the_dialogue_addon_runs_while_the_world_is_paused() -> void:
	assert_eq(DialogueManager.process_mode, Node.PROCESS_MODE_ALWAYS, "its mutations' waits go on during a conversation")

func test_a_spot_shows_its_dialogue_on_use_and_needs_a_title_it_has() -> void:
	var spot := preload("res://gamebase/modules/dialogue/dialogue_spot.tscn").instantiate() as DialogueSpot
	spot.name = "Sign"
	spot.dialogue = _dialogue()
	add_child_autofree(spot)
	assert_eq(spot.find_scene_problems(null, null), PackedStringArray())
	spot.dialogue_title = "missing"
	assert_eq(spot.find_scene_problems(null, null), PackedStringArray(["dialogue spot 'Sign' shows no dialogue under 'missing'"]))
	spot.dialogue_title = "start"
	spot.interactable.interacted.emit(self)
	assert_true(Dialogue.is_showing(), "using it shows its dialogue")
	(Dialogue.get("_balloon") as Node).free()
	assert_false(Dialogue.is_showing())

func _service() -> DialogueService:
	var service := DialogueService.new()
	add_child_autofree(service)
	return service

func _dialogue() -> DialogueResource:
	return DialogueManager.create_resource_from_text(DIALOGUE_TEXT) as DialogueResource

func _on_toast(message: String) -> void:
	_toasts.append(message)
