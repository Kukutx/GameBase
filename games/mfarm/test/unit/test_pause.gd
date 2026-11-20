extends GutTest

## MFarm's pause menu, the old game's paper with its tabs leaning by the right
## edge: the sheet each tab brings to the top, the volumes, back to the game,
## the old words, and that it fits each view the game is laid out in.

const PauseScene := preload("res://game/ui/pause.tscn")
const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")

var _locale := ""

func before_each() -> void:
	_locale = TranslationServer.get_locale()

func after_each() -> void:
	TranslationServer.set_locale(_locale)
	GameSettings.reset_all()
	InputLock.clear()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()

func _pause() -> MFarmPause:
	var menu := PauseScene.instantiate() as MFarmPause
	add_child_autofree(menu)
	return menu

func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()

static func _middle(control: Control) -> Vector2:
	return control.position + control.size / 2

func test_the_hud_pauses_with_the_old_paper_menu() -> void:
	var hud := (load("res://game/ui/hud.tscn") as PackedScene).get_state()
	var found := false
	for node: int in hud.get_node_count():
		if hud.get_node_name(node) == &"PauseMenu":
			found = hud.get_node_instance(node) == PauseScene
	assert_true(found, "the gear and Esc open MFarm's own pause menu")

func test_the_settings_sheet_is_on_top_with_the_old_tabs_leaning_by_the_right_edge() -> void:
	var menu := _pause()
	menu.open()
	assert_true(menu.visible)
	assert_true(get_tree().paused, "the world stands still, as the old timeScale 0 did")
	assert_eq(menu.shown, MFarmPause.Sheet.SETTINGS, "设置 on top, as in the old menu")
	assert_eq(menu.paper.get_child(-1), menu.sheets[MFarmPause.Sheet.SETTINGS], "drawn on top")
	assert_eq(_focus(), menu.music_slider, "the keys and a gamepad start on the music")
	var tabs := menu.tabs
	assert_eq(tabs[MFarmPause.Sheet.REST].text, "Rest")
	assert_eq(tabs[MFarmPause.Sheet.SETTINGS].text, "Setup")
	assert_eq(tabs[MFarmPause.Sheet.SAVES].text, "Saves")
	assert_eq(_middle(tabs[MFarmPause.Sheet.SETTINGS]), Vector2(240, 105), "设置 stood 105 pixels down the paper")
	assert_eq(_middle(tabs[MFarmPause.Sheet.REST]), Vector2(240, 130), "休息 25 below it")
	assert_eq(_middle(tabs[MFarmPause.Sheet.SAVES]), Vector2(240, 80), "存档 25 above it")
	for tab: Button in tabs.values():
		assert_eq(tab.size, MFarmPause.TAB_SIZE, "the old tab's size, whatever its word")
		assert_almost_eq(tab.rotation_degrees, 20.0, 0.001, "the old tabs leaned")
	menu.close()

func test_a_tab_brings_its_sheet_to_the_top_and_it_stays_there() -> void:
	var menu := _pause()
	menu.open()
	menu.tabs[MFarmPause.Sheet.REST].pressed.emit()
	assert_eq(menu.shown, MFarmPause.Sheet.REST)
	assert_true(menu.contents[MFarmPause.Sheet.REST].visible)
	assert_false(menu.contents[MFarmPause.Sheet.SETTINGS].visible, "a sheet underneath shows nothing to press")
	assert_eq(_focus(), menu.resume_button, "返回游戏 first")
	assert_eq(menu.quit_button.visible, GameTitleBase.can_quit(), "a web page has no quit")
	menu.resume_button.pressed.emit()
	assert_false(menu.visible, "back to the game, which the old notes asked for")
	assert_false(get_tree().paused)
	menu.open()
	assert_eq(menu.shown, MFarmPause.Sheet.REST, "the sheet on top stays there")
	assert_eq(_focus(), menu.resume_button)
	menu.tabs[MFarmPause.Sheet.SAVES].pressed.emit()
	assert_eq(_focus(), menu.save_button)
	assert_eq(menu.load_button.disabled, not SaveManager.has_save())
	menu.tabs[MFarmPause.Sheet.REST].pressed.emit()
	menu.title_button.pressed.emit()
	assert_true(menu.confirm_title.visible, "it asks before leaving the game")
	menu.confirm_title.hide()
	menu.close()

func test_the_sliders_turn_the_music_and_the_sounds_and_the_rest_is_a_press_away() -> void:
	GameSettings.set_music_volume(0.6)
	var master := GameSettings.master_volume
	var menu := _pause()
	menu.open()
	assert_almost_eq(menu.music_slider.value, 0.6, 0.001, "it shows the volume as it is")
	menu.music_slider.value = 0.25
	assert_almost_eq(GameSettings.music_volume, 0.25, 0.001)
	assert_almost_eq(GameSettings.master_volume, master, 0.001, "the music alone, as its words say")
	menu.sounds_slider.value = 0.5
	assert_almost_eq(GameSettings.sounds_volume, 0.5, 0.001)
	menu.settings_button.pressed.emit()
	assert_true(menu.settings_menu.visible, "更多设置 opens the rest of the settings")
	assert_true(menu.tabs[MFarmPause.Sheet.REST].disabled, "the paper holds while they are open")
	assert_false(menu.music_slider.editable)
	GameSettings.set_music_volume(0.8)
	menu.settings_menu.close()
	assert_false(menu.tabs[MFarmPause.Sheet.REST].disabled)
	assert_true(menu.music_slider.editable)
	assert_almost_eq(menu.music_slider.value, 0.8, 0.001, "a change made there shows here")
	assert_eq(_focus(), menu.settings_button)
	menu.close()

func test_the_old_words_in_chinese() -> void:
	TranslationServer.set_locale("zh_CN")
	var menu := _pause()
	var words := PackedStringArray()
	for button: Button in menu.tabs.values() + [menu.resume_button, menu.title_button, menu.quit_button, menu.save_button, menu.load_button, menu.settings_button]:
		words.append(menu.tr(button.text))
	assert_eq(words, PackedStringArray(["存档", "休息", "设置", "返回游戏", "返回标题", "退出游戏", "保存游戏", "读取游戏", "更多设置"]))
	var labels := menu.contents[MFarmPause.Sheet.SETTINGS].find_children("*", "Label", false, false)
	assert_eq(labels.map(func(label: Label) -> String: return menu.tr(label.text)), ["背景音乐", "音效"])

func test_the_menu_fits_each_view() -> void:
	var menu := _pause()
	menu.open()
	for sheet: MFarmPause.Sheet in MFarmPause.Sheet.values():
		menu.show_sheet(sheet)
		await get_tree().process_frame
		assert_eq(await MenuFit.find_overflow_in_views(menu), PackedStringArray(), MFarmPause.Sheet.keys()[sheet])
	menu.close()
