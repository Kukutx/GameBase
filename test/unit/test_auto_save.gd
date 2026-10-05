extends GutTest

var _autosave_before := true

func before_each() -> void:
	_autosave_before = GameSettings.autosave

func after_each() -> void:
	GameSettings.autosave = _autosave_before
	GameSettings.changed.emit()

func test_disabled_autosave_pauses_timer_and_skips_request() -> void:
	GameSettings.autosave = false
	var service := AutoSaveService.new()
	add_child_autofree(service)
	await get_tree().process_frame
	var timer := service.get_node("AutosaveTimer") as Timer
	assert_not_null(timer)
	assert_true(timer.paused)
	assert_false(service.request_autosave("test"))

func test_recent_save_deduplicates_autosave_without_touching_disk() -> void:
	GameSettings.autosave = true
	var service := AutoSaveService.new()
	add_child_autofree(service)
	await get_tree().process_frame
	service.set("_last_save_msec", Time.get_ticks_msec())
	var skipped := {"reason": "", "block": ""}
	service.autosave_skipped.connect(func(reason: String, block_reason: String) -> void:
		skipped["reason"] = reason
		skipped["block"] = block_reason
	)
	assert_false(service.request_autosave("travel"))
	assert_eq(String(skipped["reason"]), "travel")
	assert_eq(String(skipped["block"]), "recent_save")

func test_window_close_request_asks_for_an_autosave() -> void:
	GameSettings.autosave = true
	var service := AutoSaveService.new()
	add_child_autofree(service)
	await get_tree().process_frame
	var skipped := {"reason": "", "block": ""}
	service.autosave_skipped.connect(func(reason: String, block_reason: String) -> void:
		skipped["reason"] = reason
		skipped["block"] = block_reason
	)
	# The test runner is not a playable location, so the request is refused before
	# anything is written; the refusal shows that the close request reached it.
	service.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(String(skipped["reason"]), "quit")
	assert_eq(String(skipped["block"]), SaveManager.get_save_block_reason())
	assert_false(String(skipped["block"]).is_empty())

func test_window_close_request_does_nothing_when_autosave_is_off() -> void:
	GameSettings.autosave = false
	var service := AutoSaveService.new()
	add_child_autofree(service)
	await get_tree().process_frame
	var requests: Array[String] = []
	service.autosave_skipped.connect(func(reason: String, _block_reason: String) -> void: requests.append(reason))
	service.autosave_completed.connect(func(_success: bool, reason: String) -> void: requests.append(reason))
	service.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(requests.size(), 0)
