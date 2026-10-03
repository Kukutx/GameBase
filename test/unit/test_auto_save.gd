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
