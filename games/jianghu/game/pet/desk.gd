class_name JianghuDesk
extends Control

## The hero's place, the game's one location: the hero, their scroll (the
## panel), the lines and numbers that float up, and on a window the landscape
## behind them. It lays these out for the mode the window is in
## (`JianghuDeskWindow`) and tells the hero's news as it comes from
## `Cultivation`.

const SETTINGS_MENU := preload("res://tiamat/core/ui/settings_menu.tscn")
## How far above the bottom the hero stands on the desktop and on the ledge.
const PET_FOOT := 10.0
const LEDGE := 56.0
const FLOATER_SECONDS := 1.8
const MAX_FLOATERS := 5
## Wide views put the panel beside the hero instead of above.
const WIDE := 700.0

@onready var scenery: JianghuScenery = $Scenery
@onready var pet: JianghuPet = $Pet
@onready var floaters: Control = $Floaters
@onready var panel: JianghuPanel = $Panel
@onready var report: JianghuReportCard = $Report
@onready var desk_window: JianghuDeskWindow = $DeskWindow

var _settings: SettingsMenu
## The hero's place along the ledge in a window, from 0 to 1.
var _ledge_x := 0.5

func _ready() -> void:
	panel.desk_window = desk_window
	panel.close_requested.connect(_set_panel_open.bind(false))
	panel.settings_requested.connect(_open_settings)
	panel.pat_requested.connect(_pat)
	pet.clicked.connect(_on_pet_clicked)
	pet.dragged.connect(_on_pet_dragged)
	pet.drag_started.connect(func() -> void: pet.say(_held_line(), 2.0))
	pet.drag_ended.connect(desk_window.remember_position)
	pet.strolled.connect(_on_pet_strolled)
	report.closed.connect(_update_clickable)
	desk_window.mode_changed.connect(func(_on: bool) -> void: _layout())
	resized.connect(_layout)
	Cultivation.fought.connect(_on_fought)
	Cultivation.advanced.connect(_on_advanced)
	Cultivation.art_learned.connect(_on_art_learned)
	Cultivation.champion_crowned.connect(_on_champion)
	Cultivation.changed.connect(_on_changed)
	panel.visible = not desk_window.pet_mode
	_layout()
	_on_changed()
	_show_away_report.call_deferred()

func _process(_delta: float) -> void:
	# The hero is the location's player, which travel places at the perch; its
	# place is the desk's to keep.
	pet.position = _pet_spot()
	_update_clickable()

func _pet_spot() -> Vector2:
	if desk_window.pet_mode:
		return Vector2(size.x / 2.0, size.y - PET_FOOT)
	var margin := 40.0
	var span := size.x * (0.55 if size.x >= WIDE else 1.0) - margin * 2.0
	return Vector2(margin + span * _ledge_x, size.y - LEDGE + 6.0)

func _layout() -> void:
	var view := size
	scenery.visible = not desk_window.pet_mode
	pet.position = _pet_spot()
	panel.reset_size()
	if not desk_window.pet_mode and view.x >= WIDE:
		panel.position = Vector2(view.x - panel.size.x - 24.0, (view.y - panel.size.y) / 2.0)
	else:
		panel.position = Vector2((view.x - panel.size.x) / 2.0, maxf(pet.position.y - 104.0 - panel.size.y, 4.0))
	report.position = (view - report.size) / 2.0
	_update_clickable()

## What the player can click in pet mode: the hero, and the panel or a card
## while one shows; the rest of the window lets clicks through.
func _update_clickable() -> void:
	if not desk_window.pet_mode:
		return
	if _settings != null and _settings.visible or report.visible:
		desk_window.set_clickable(Rect2(Vector2.ZERO, size))
		return
	var area := pet.get_hit_rect()
	if pet.bubble.visible:
		area = area.merge(Rect2(pet.to_global(pet.bubble.position), pet.bubble.size))
	if panel.visible:
		area = area.merge(panel.get_global_rect())
	desk_window.set_clickable(area.grow(2.0))

func _set_panel_open(open: bool) -> void:
	panel.visible = open
	if open:
		_layout()
		panel.refresh()
	GameAudio.play_cue(&"sfx_scroll")
	_update_clickable()

func _on_pet_clicked() -> void:
	_pat()
	if desk_window.pet_mode:
		_set_panel_open(not panel.visible)
	elif not panel.visible:
		_set_panel_open(true)

func _pat() -> void:
	if Cultivation.pat():
		pet.cheer()
		pet.say(tr("Thank you! I'll work twice as hard!"))
		GameAudio.play_cue(&"sfx_cheer")
		_float_text(tr("Cultivation ×2"), JianghuStyle.GOLD)
	else:
		pet.say(_idle_line())
		GameAudio.play_cue(&"sfx_tap")

func _on_pet_dragged(screen_delta: Vector2) -> void:
	if desk_window.pet_mode:
		desk_window.move_window(screen_delta)
	else:
		var span := size.x * (0.55 if size.x >= WIDE else 1.0) - 80.0
		_ledge_x = clampf(_ledge_x + screen_delta.x / get_viewport().get_final_transform().get_scale().x / span, 0.0, 1.0)
		_layout()

func _on_pet_strolled(distance: float) -> void:
	if desk_window.pet_mode:
		var screen := distance * desk_window.get_view_scale()
		if desk_window.can_walk(screen):
			desk_window.move_window(Vector2(screen, 0.0))
		else:
			pet.turn_back()
		return
	var span := size.x * (0.55 if size.x >= WIDE else 1.0) - 80.0
	var next := _ledge_x + distance / span
	if next < 0.0 or next > 1.0:
		pet.turn_back()
	_ledge_x = clampf(next, 0.0, 1.0)
	_layout()

func _on_changed() -> void:
	var realm := Cultivation.get_realm_data()
	if realm != null:
		pet.set_aura(realm.aura)
	scenery.set_region(Cultivation.get_region_data())

func _on_fought(entry: Dictionary) -> void:
	if Cultivation.is_playing_out() or report.visible:
		return
	if bool(entry.won):
		_float_text(tr("+%s silver") % JianghuNumbers.format(float(entry.silver)), JianghuStyle.GOLD)
		if bool(entry.boss):
			pet.cheer()
			pet.say(JianghuRoamPage.fight_line(entry), 5.0)
			GameAudio.play_cue(&"sfx_victory")
		else:
			GameAudio.play_cue(&"sfx_clash")
	else:
		_float_text(tr("Defeated, resting"), JianghuStyle.SEAL)
		if bool(entry.boss):
			pet.say(tr("Too strong... I need more training."))
		GameAudio.play_cue(&"sfx_defeat")

func _on_advanced(_realm: int, layer: int, new_realm: bool) -> void:
	if Cultivation.is_playing_out() or report.visible:
		return
	if new_realm:
		var data := Cultivation.get_realm_data()
		pet.cheer()
		pet.say(tr("Breakthrough! I have entered %s!") % tr(data.display_name), 5.0)
		GameAudio.play_cue(&"sfx_breakthrough")
	else:
		_float_text(tr("Layer %d!") % layer, JianghuStyle.JADE)
		GameAudio.play_cue(&"sfx_layer")

func _on_art_learned(art_id: StringName, level: int) -> void:
	var art := JianghuArtData.find(art_id)
	if art != null:
		_float_text(tr("%s level %d") % [tr(art.display_name), level], JianghuStyle.SEAL)

func _on_champion() -> void:
	pet.cheer()
	report.show_champion()
	GameAudio.play_cue(&"sfx_breakthrough")

func _show_away_report() -> void:
	var away := Cultivation.take_away_report()
	if not away.is_empty():
		report.show_away(away)
		_layout()

func _open_settings() -> void:
	if _settings == null:
		_settings = SETTINGS_MENU.instantiate() as SettingsMenu
		add_child(_settings)
		_settings.closed.connect(_update_clickable)
	_settings.open()
	_update_clickable()

func _float_text(text: String, color: Color) -> void:
	if floaters.get_child_count() >= MAX_FLOATERS:
		floaters.get_child(0).queue_free()
	var label := JianghuStyle.label(text, 13, color)
	label.add_theme_color_override("font_outline_color", Color(1, 0.98, 0.94))
	label.add_theme_constant_override("font_outline_size", 4)
	floaters.add_child(label)
	label.reset_size()
	var start := pet.position + Vector2(34.0 + randf_range(-4.0, 8.0), -96.0 + floaters.get_child_count() * 17.0)
	label.position = start
	var tween := label.create_tween()
	tween.set_parallel()
	var rise := 0.0 if GameSettings.reduced_motion else 34.0
	tween.tween_property(label, "position:y", start.y - rise, FLOATER_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FLOATER_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _idle_line() -> String:
	var hour := int(Time.get_datetime_dict_from_system().hour)
	if hour >= JianghuPet.NIGHT_FROM or hour < JianghuPet.NIGHT_UNTIL:
		return tr("Zzz... the moon is bright tonight...")
	var lines: Array[String] = [
		tr("A sword is only as sharp as the hand that holds it."),
		tr("One more round of breathing..."),
		tr("Shh, I'm circulating my qi."),
		tr("You work hard, and I'll train hard!"),
		tr("Someday I'll be first under heaven."),
		tr("The jianghu isn't all fighting. It's people, too."),
		tr("Have some tea and rest your eyes."),
		tr("Ahem. A true master never panics."),
	]
	return lines[randi() % lines.size()]

func _held_line() -> String:
	var lines: Array[String] = [tr("Hey! Put me down!"), tr("Whoa, flying!"), tr("Light-body skill? No, it's you!")]
	return lines[randi() % lines.size()]
