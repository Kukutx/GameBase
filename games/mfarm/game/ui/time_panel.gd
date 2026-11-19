class_name MFarmTimePanel
extends Control

## The clock in the top right corner, as the old game drew it: a dial of
## six blocks that fill as the day goes on (one for every four hours), a
## round window on the sun and moon that turns with the hour, the date on a
## hanging plank, the time of day and the season's picture beneath it. The
## little gear opens the pause menu.

const SIZE := Vector2(75, 74)
const SEASONS: Array[String] = ["ui_time_12", "ui_time_13", "ui_time_14", "ui_time_15"]
const BLOCKS := 6
const DATE_COLOR := Color(0.95, 0.88, 0.72)
## The year the old game's calendar starts in.
const START_YEAR := 2023
const DAYS_PER_MONTH := 30

var _sun_moon: TextureRect
var _blocks: Array[TextureRect] = []
var _date: Label
var _time: Label
var _season: TextureRect
var _turn: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	position = Vector2(640 - SIZE.x, 0)
	MFarmUiArt.place(self, MFarmUiArt.image(MFarmUiArt.texture("ui_time_16"), SIZE), Vector2.ZERO)
	var window := MFarmUiArt.image(MFarmUiArt.texture("ui_time_17"), Vector2(25, 25))
	window.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	MFarmUiArt.place(self, window, Vector2(41, 9))
	_sun_moon = MFarmUiArt.image(MFarmUiArt.texture("ui_time_00"), Vector2(63, 63))
	_sun_moon.pivot_offset = Vector2(31.5, 31.5)
	MFarmUiArt.place(window, _sun_moon, Vector2(-19, -2))
	for index: int in BLOCKS:
		var block := MFarmUiArt.image(MFarmUiArt.texture("ui_time_%02d" % (5 + index)), Vector2(33, 33))
		_blocks.append(MFarmUiArt.place(self, block, Vector2(30, 12)) as TextureRect)
	_date = MFarmUiArt.label("", 8, DATE_COLOR)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date.size = Vector2(60, 10)
	MFarmUiArt.place(self, _date, Vector2(12.5, 50))
	MFarmUiArt.place(self, MFarmUiArt.panel("ui_time_18", Vector2(50, 20)), Vector2(18.6, 64.3)).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time = MFarmUiArt.label("", 8, DATE_COLOR)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.size = Vector2(36, 12)
	MFarmUiArt.place(self, _time, Vector2(25.5, 68.5))
	MFarmUiArt.place(self, MFarmUiArt.image(MFarmUiArt.texture("ui_time_11"), Vector2(32, 16)), Vector2(26.8, 83))
	_season = MFarmUiArt.place(self, MFarmUiArt.image(null, Vector2(32, 16)), Vector2(26.8, 83)) as TextureRect
	var settings := TextureButton.new()
	settings.texture_normal = MFarmUiArt.texture("ui_button_set")
	settings.ignore_texture_size = true
	settings.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	settings.size = Vector2(9, 9)
	settings.tooltip_text = "Menu"
	settings.pressed.connect(_open_menu)
	MFarmUiArt.place(self, settings, Vector2(SIZE.x - 12, 3))
	WorldClock.minute_changed.connect(_on_minute_changed)
	WorldClock.hour_changed.connect(_on_hour_changed)
	_on_minute_changed(WorldClock.day, WorldClock.minute_of_day)
	_on_hour_changed(WorldClock.day, WorldClock.get_hour())
	_sun_moon.rotation_degrees = _dial_angle(WorldClock.get_hour())

## The date as the old game wrote it: year, month and day, thirty days to a
## month and twelve months, three to a season, to a year, laid out by
## `format` (the old game's 2023年01月01日 in Chinese).
static func date_text(day: int, format := "%d.%02d.%02d") -> String:
	var days := maxi(day, 1) - 1
	var month := days / DAYS_PER_MONTH
	return format % [START_YEAR + month / 12, month % 12 + 1, days % DAYS_PER_MONTH + 1]

## How many of the dial's blocks are lit at `hour`: one more for every four
## hours (the old game left the dial dark until four, then skipped a block).
static func lit_blocks(hour: int) -> int:
	return clampi(hour / 4 + 1, 1, BLOCKS)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _date != null:
		_date.text = date_text(WorldClock.day, tr("%d.%02d.%02d"))

func _on_minute_changed(_day: int, minute_of_day: int) -> void:
	_time.text = "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]

func _on_hour_changed(day: int, hour: int) -> void:
	_date.text = date_text(day, tr("%d.%02d.%02d"))
	_season.texture = MFarmUiArt.texture(SEASONS[clampi(WorldClock.get_season_index(), 0, SEASONS.size() - 1)])
	var lit := lit_blocks(hour)
	for index: int in _blocks.size():
		_blocks[index].visible = index < lit
	if _turn != null and _turn.is_valid():
		_turn.kill()
	_turn = create_tween()
	_turn.tween_property(_sun_moon, ^"rotation_degrees", _dial_angle(hour), 1.0)

# The old dial turned to hour * 15 - 90 degrees counterclockwise; it takes
# the short way round, as the old tween did.
func _dial_angle(hour: int) -> float:
	var target := -(hour * 15.0 - 90.0)
	var current := _sun_moon.rotation_degrees
	return current + wrapf(target - current, -180.0, 180.0)

func _open_menu() -> void:
	var menu := get_tree().get_first_node_in_group(&"pause_menu")
	if menu != null and menu.has_method(&"open"):
		menu.call(&"open")
