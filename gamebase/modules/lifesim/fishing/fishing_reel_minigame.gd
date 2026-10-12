class_name FishingReelMiniGame
extends MiniGame

## Stop the moving marker inside the catch zone to land the fish. A harder fish
## has a smaller zone and a faster marker; each miss costs one attempt.
##
## Settings: `difficulty` (1-10), `zone_scale` (multiplies the zone width, e.g.
## from a fishing buff), `attempts`, `seed` (places the zone deterministically).

const BAR_WIDTH := 220.0
const BAR_HEIGHT := 14.0

## Zone and marker positions are fractions of the bar width.
var zone_start := 0.4
var zone_width := 0.3
## Bar widths per second.
var marker_speed := 0.7
var marker := 0.0
var attempts_left := 3

var _direction := 1.0
var _zone_rect: ColorRect
var _marker_rect: ColorRect
var _status: Label

func setup(settings: Dictionary) -> void:
	var difficulty := clampi(int(settings.get("difficulty", 1)), 1, 10)
	zone_width = clampf((0.34 - 0.025 * float(difficulty - 1)) * float(settings.get("zone_scale", 1.0)), 0.08, 0.9)
	marker_speed = 0.6 + 0.12 * float(difficulty - 1)
	attempts_left = maxi(int(settings.get("attempts", 3)), 1)
	var rng := GameRandom.stream("reel:%s" % str(settings.get("seed", 0)))
	zone_start = rng.randf_range(0.1, 0.9 - zone_width)
	_build()
	_refresh()

func _process(delta: float) -> void:
	if not is_finished():
		advance(delta)

## Moves the marker; it bounces between the ends of the bar.
func advance(delta: float) -> void:
	marker += _direction * marker_speed * delta
	if marker >= 1.0:
		marker = 2.0 - marker
		_direction = -1.0
	elif marker <= 0.0:
		marker = -marker
		_direction = 1.0
	marker = clampf(marker, 0.0, 1.0)
	_refresh()

## The player stops the marker. Returns whether it was inside the zone.
func press() -> bool:
	if is_finished():
		return false
	var hit := marker >= zone_start and marker <= zone_start + zone_width
	if hit:
		finish(MiniGameResult.won(attempts_left))
		return true
	attempts_left -= 1
	_refresh()
	if attempts_left <= 0:
		finish(MiniGameResult.lost())
	return false

func _unhandled_input(event: InputEvent) -> void:
	if has_input() and event.is_action_pressed("interact"):
		press()
		get_viewport().set_input_as_handled()
		return
	super(event)

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("Reel it in!")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.color = Color(0.12, 0.2, 0.3)
	box.add_child(bar)
	_zone_rect = ColorRect.new()
	_zone_rect.color = Color(0.35, 0.75, 0.4)
	bar.add_child(_zone_rect)
	_marker_rect = ColorRect.new()
	_marker_rect.color = Color(0.95, 0.9, 0.6)
	bar.add_child(_marker_rect)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	panel.position = -panel.get_combined_minimum_size() * 0.5

func _refresh() -> void:
	if _zone_rect == null:
		return
	_zone_rect.position = Vector2(zone_start * BAR_WIDTH, 0.0)
	_zone_rect.size = Vector2(zone_width * BAR_WIDTH, BAR_HEIGHT)
	_marker_rect.position = Vector2(marker * BAR_WIDTH - 1.0, -2.0)
	_marker_rect.size = Vector2(3.0, BAR_HEIGHT + 4.0)
	_status.text = tr("Press %s in the green zone · tries left: %d") % [InputPrompts.get_action_prompt(&"interact"), attempts_left]
