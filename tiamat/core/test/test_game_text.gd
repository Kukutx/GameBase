extends GutTest

## Lists the player reads in their language, and lines of parts that wrap
## between parts, after a dot (`GameText`).

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

func test_a_line_of_parts_wraps_after_a_dot_never_before_one() -> void:
	var parts := PackedStringArray(["Attack 6", "Defense 2", "Move 3"])
	assert_eq(GameText.parts(parts), "Attack 6\u00a0· Defense 2\u00a0· Move 3")
	assert_eq(GameText.parts(parts, true), "Attack\u00a06\u00a0· Defense\u00a02\u00a0· Move\u00a03", "each part kept together")
	assert_eq(GameText.parts(PackedStringArray(["Attack 6"])), "Attack 6", "one part alone")
	var font := ThemeDB.fallback_font
	var whole := GameText.parts(parts, true)
	var one_line := font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
	for width: float in [one_line * 0.4, one_line * 0.6, one_line * 0.8]:
		var lines := _wrap(whole, font, width)
		assert_gt(lines.size(), 1, "%d wide wraps" % width)
		for line: String in lines:
			assert_false(line.strip_edges().begins_with("·"), "'%s' does not start with the dot" % line)
		for part: String in parts:
			assert_true(Array(lines).any(func(line: String) -> bool: return line.contains(part.replace(" ", GameText.NO_BREAK_SPACE))), "%s stays on one line" % part)

func test_a_line_put_together_elsewhere_keeps_its_dots_off_the_start_of_a_line() -> void:
	assert_eq(GameText.keep_dots("Hp 30 · Hits for 8 · Drops Gel"), "Hp 30\u00a0· Hits for 8\u00a0· Drops Gel")
	assert_eq(GameText.keep_dots("Hp 30\u00a0· Drops Gel"), "Hp 30\u00a0· Drops Gel", "a dot kept already stays as it is")
	assert_eq(GameText.keep_dots("Gel, Ore"), "Gel, Ore")
	var font := ThemeDB.fallback_font
	var kept := GameText.keep_dots("Hp 30 · Hits for 8 · Inflicts Burning · Immune to Poison · Drops Gel")
	var one_line := font.get_string_size(kept, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
	for share: float in [0.2, 0.3, 0.45, 0.6, 0.8]:
		for line: String in _wrap(kept, font, one_line * share):
			assert_false(line.strip_edges().begins_with("·"), "'%s' does not start with the dot" % line)

# The lines `text` takes in `font` at 16 when it wraps at `width`.
func _wrap(text: String, font: Font, width: float) -> PackedStringArray:
	var paragraph := TextParagraph.new()
	paragraph.add_string(text, font, 16)
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var lines := PackedStringArray()
	for index: int in paragraph.get_line_count():
		var range_of := paragraph.get_line_range(index)
		lines.append(text.substr(range_of.x, range_of.y - range_of.x))
	return lines
