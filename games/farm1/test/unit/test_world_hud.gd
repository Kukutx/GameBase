extends GutTest

## Farm1's HUD over the world: its vitals and money share the top line with
## the clock, each keeping to its half however long the numbers grow, in the
## game's own view and in a phone's wider one.

const HUD := preload("res://game/world/world_hud.tscn")

var _money := 0
var _day := 0
var _minute := 0

func before_each() -> void:
	_money = Wallet.money
	_day = WorldClock.day
	_minute = WorldClock.minute_of_day

func after_each() -> void:
	Wallet.set_money(_money)
	WorldClock.set_time(_day, _minute)

func test_the_vitals_and_the_clock_keep_to_their_halves_of_the_top_line() -> void:
	Wallet.set_money(9876543)
	WorldClock.set_time(112, 23 * 60 + 50)
	for size: Vector2i in [Vector2i(480, 270), Vector2i(600, 270)]:
		var view := SubViewport.new()
		view.size = size
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child_autofree(view)
		var hud := HUD.instantiate()
		view.add_child(hud)
		await get_tree().process_frame
		await get_tree().process_frame
		var stats := hud.get_node("Stats") as Label
		var clock := hud.get_node("Clock") as Label
		assert_string_contains(stats.text, "9876543")
		assert_false(stats.get_global_rect().intersects(clock.get_global_rect()), "the two halves never overlap in %s" % size)
		for label: Label in [stats, clock]:
			var font_size := label.get_theme_font_size(&"font_size")
			assert_gte(font_size, ReadableText.min_font_size(Vector2(size)), "%s still reads on a phone" % label.name)
			assert_true(label.clip_text, "%s cuts what does not fit rather than run over" % label.name)
		var drawn := stats.get_theme_font(&"font").get_string_size(stats.text, HORIZONTAL_ALIGNMENT_LEFT, -1, stats.get_theme_font_size(&"font_size")).x
		assert_true(drawn <= stats.size.x or stats.get_theme_font_size(&"font_size") == ReadableText.min_font_size(Vector2(size)), "the vitals shrink to fit their half")
