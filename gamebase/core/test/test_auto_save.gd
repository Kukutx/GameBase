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

func test_the_save_indicator_shows_each_autosave_and_then_goes() -> void:
	var reduced_motion := GameSettings.reduced_motion
	var indicator := SaveIndicator.new()
	indicator.seconds_shown = 0.05
	indicator.fade_seconds = 0.05
	add_child_autofree(indicator)
	assert_false(indicator.visible)
	AutoSave.autosave_completed.emit(false, "interval")
	assert_false(indicator.visible, "a failed autosave is a toast instead")
	AutoSave.autosave_completed.emit(true, "travel")
	assert_true(indicator.visible)
	assert_eq(indicator.text, "Autosaved")
	await wait_until(func() -> bool: return not indicator.visible, 1.0)
	assert_false(indicator.visible)
	GameSettings.reduced_motion = true
	indicator.show_saved()
	await wait_until(func() -> bool: return not indicator.visible, 1.0)
	assert_false(indicator.visible)
	assert_eq(indicator.modulate.a, 1.0, "with reduced motion it goes without a fade")
	GameSettings.reduced_motion = reduced_motion
