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
	events.toast("Travel failed")
	events.toastf("Slept until %s %d", ["Spring", 3])
	assert_eq(observed[0], "旅行失败")
	assert_eq(observed[1], "睡到了春季 3日")

	TranslationServer.set_locale("en")
	events.toast("Travel failed")
	events.toastf("Slept until %s %d", ["Spring", 3])
	assert_eq(observed[2], "Travel failed")
	assert_eq(observed[3], "Slept until Spring 3")
	TranslationServer.set_locale(previous)
