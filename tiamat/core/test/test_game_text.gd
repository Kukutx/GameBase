extends GutTest

## Lists the player reads in their language (`GameText`).

var _locale: String

func before_each() -> void:
	_locale = TranslationServer.get_locale()

func after_each() -> void:
	TranslationServer.set_locale(_locale)

func test_a_list_reads_in_the_player_s_language() -> void:
	TranslationServer.set_locale("en")
	assert_eq(GameText.list(PackedStringArray(["Gel", "Ore"])), "Gel, Ore")
	assert_eq(GameText.list(PackedStringArray(["Gel"])), "Gel", "one part alone")
	assert_eq(GameText.list(PackedStringArray()), "", "none")
	TranslationServer.set_locale("zh_CN")
	assert_eq(GameText.list(PackedStringArray(["凝胶", "矿石"])), "凝胶、矿石")
