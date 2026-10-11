extends GutTest

func test_static_and_formatted_toasts_translate_at_emit_time() -> void:
	var events := GlobalGameEvents.new()
	add_child_autofree(events)
	var observed: Array[String] = []
	events.toast_requested.connect(func(message: String) -> void:
		observed.append(message)
	)
	var previous := TranslationServer.get_locale()

	TranslationServer.set_locale("zh_CN")
	events.toast("Inventory is full")
	events.toastf("Caught %s", ["River Trout"])
	assert_eq(observed[0], "背包已满")
	assert_eq(observed[1], "钓到了河鳟")

	TranslationServer.set_locale("en")
	events.toast("Inventory is full")
	events.toastf("Caught %s", ["River Trout"])
	assert_eq(observed[2], "Inventory is full")
	assert_eq(observed[3], "Caught River Trout")
	TranslationServer.set_locale(previous)
