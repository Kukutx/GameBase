extends GutTest

## The window opens where the player left it (`WindowMemory`), and a phone
## keeps its full screen (`GameSettingsService.window_mode_for()`).

const TEST_PATH := "user://window_memory_test.json"

const SCREEN := Rect2i(0, 0, 1920, 1040)
const SECOND_SCREEN := Rect2i(1920, 0, 2560, 1400)

func after_each() -> void:
	JsonFile.remove(TEST_PATH)

func test_a_window_on_a_screen_opens_where_it_was() -> void:
	var screens: Array[Rect2i] = [SCREEN, SECOND_SCREEN]
	assert_eq(WindowMemory.place(Rect2i(200, 120, 1280, 720), screens), Rect2i(200, 120, 1280, 720))
	assert_eq(WindowMemory.place(Rect2i(2400, 300, 1280, 720), screens), Rect2i(2400, 300, 1280, 720), "on the second screen")
	assert_eq(WindowMemory.place(Rect2i(-500, 100, 1280, 720), screens), Rect2i(-500, 100, 1280, 720), "half off the left edge, its top still to grab")

func test_a_window_on_a_screen_now_gone_opens_in_the_middle_of_the_first() -> void:
	var screens: Array[Rect2i] = [SCREEN]
	assert_eq(WindowMemory.place(Rect2i(2400, 300, 1280, 720), screens), Rect2i(320, 160, 1280, 720))
	assert_eq(WindowMemory.place(Rect2i(200, -400, 1280, 720), screens), Rect2i(320, 160, 1280, 720), "its top above every screen")

func test_no_window_opens_larger_than_its_screen() -> void:
	var screens: Array[Rect2i] = [SCREEN]
	assert_eq(WindowMemory.place(Rect2i(0, 0, 3840, 2160), screens), Rect2i(0, 0, 1920, 1040))
	assert_eq(WindowMemory.place(Rect2i(5000, 0, 3840, 2160), screens), Rect2i(0, 0, 1920, 1040))

func test_nothing_saved_leaves_the_window_as_the_game_opens_it() -> void:
	var screens: Array[Rect2i] = [SCREEN]
	assert_eq(WindowMemory.place(Rect2i(), screens), Rect2i())
	assert_eq(WindowMemory.place(Rect2i(0, 0, 640, 360), [] as Array[Rect2i]), Rect2i())

func test_the_file_holds_only_values_and_a_wrong_one_is_nothing() -> void:
	JsonFile.write(TEST_PATH, {"rect": [10, 20, 640, 360], "maximized": true})
	var data := WindowMemory.read(TEST_PATH)
	assert_eq(WindowMemory.rect_of(data), Rect2i(10, 20, 640, 360))
	assert_true(bool(data.get("maximized")))
	for wrong: Variant in [[10, 20, 640], ["10", 20, 640, 360], [10, 20, 0, 360], "10,20,640,360"]:
		assert_eq(WindowMemory.rect_of({"rect": wrong}), Rect2i(), "%s is no rect" % [wrong])
	JsonFile.write(TEST_PATH, [1, 2, 3])
	assert_eq(WindowMemory.read(TEST_PATH), {}, "a file of no object reads as nothing")

func test_a_test_run_keeps_no_window() -> void:
	assert_false(WindowMemory.is_kept(), "headless or from the editor")
	WindowMemory.remember(TEST_PATH)
	assert_false(FileAccess.file_exists(TEST_PATH))

func test_a_phone_keeps_its_full_screen_and_a_computer_follows_the_setting() -> void:
	var windowed := DisplayServer.WINDOW_MODE_WINDOWED
	var maximized := DisplayServer.WINDOW_MODE_MAXIMIZED
	var full := DisplayServer.WINDOW_MODE_FULLSCREEN
	assert_eq(GameSettingsService.window_mode_for(false, full, true), -1, "a phone in full screen stays so")
	assert_eq(GameSettingsService.window_mode_for(true, maximized, true), -1, "a phone takes no mode")
	assert_eq(GameSettingsService.window_mode_for(true, windowed, false), full)
	assert_eq(GameSettingsService.window_mode_for(false, full, false), windowed)
	assert_eq(GameSettingsService.window_mode_for(false, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, false), windowed)
	assert_eq(GameSettingsService.window_mode_for(false, maximized, false), -1, "a maximized window stays maximized")
	assert_eq(GameSettingsService.window_mode_for(true, full, false), -1)
