class_name GameAudioService
extends Node

## Plays the game's music and sounds by cue (`AudioCueData`).
##
## Music plays one track at a time on the Music bus: a new one fades in over
## its cue's `fade_seconds` while the one before fades out. Each location
## plays its own music (`WorldLocationData.music_cue_id`) when the scene
## changes, and a music cue played directly (`play_cue()`) takes its place.
## Music pushed over it (`push_music()`: a fight's, a minigame's) plays instead
## until it is popped (`pop_music()`), and the music beneath then comes back
## where it stopped. Asking for the music that plays leaves it playing; a
## location without music fades it out.
##
## Sounds play on the Sounds bus, up to `SFX_CHANNEL_COUNT` heard everywhere
## alike and `POSITIONAL_CHANNEL_COUNT` heard from places at once, and each
## cue at most `AudioCueData.max_voices` times at once; past either, the
## oldest stops. A sound played at a place in the world (`play_cue_at()`) is
## heard from there, fainter with distance up to its cue's
## `hearing_distance`. Each event listed in `GameDefinition.event_cues` plays
## its cue, where it happened when the event carries a `position`.
##
## The menus sound as the game sets (`GameDefinition.menu_*_cue_id`): a menu
## opening and closing (`GameEvents.menu_opened`, `menu_closed`), a button
## pressed and the focus moving with the keys or a gamepad (`NAVIGATION_ACTIONS`;
## not a click, the pointer or a menu focusing its first control); of those
## asked for in one frame only the most telling plays (`MenuSound`).
##
## The volumes are the player's, which `GameSettings` sets on the buses. Audio
## keeps playing while the world is paused. The service saves nothing.

signal cue_requested(audio_cue_id: StringName)
signal cue_started(audio_cue_id: StringName)
signal music_changed(audio_cue_id: StringName)

## The sounds of the menus, the least telling first: of those asked for in
## one frame, the last in this order plays.
enum MenuSound { FOCUS, PRESS, CLOSE, OPEN }

## Sounds heard everywhere alike at once.
const SFX_CHANNEL_COUNT := 8
## Sounds heard from a place in the world at once.
const POSITIONAL_CHANNEL_COUNT := 8
## The actions that move the focus, which sounds when it moves.
const NAVIGATION_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

# Two players, so a track fades in while the one before fades out.
var _music_players: Array[AudioStreamPlayer] = []
# The player of the music that plays now.
var _music_index := 0
var _music_fades: Dictionary[AudioStreamPlayer, Tween] = {}
var _current_music_cue_id: StringName = &""
# The music beneath what is pushed: the location's, or the cue played last.
var _base_music_id: StringName = &""
# Music pushed over it, the oldest first: {"layer", "cue_id"}.
var _pushed: Array[Dictionary] = []
# cue id -> the second its music stopped at when music was pushed over it.
var _resume_at: Dictionary[StringName, float] = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _positional_players: Array[AudioStreamPlayer2D] = []
# channel -> {"cue_id", "order"}: what a channel plays and how lately it began.
var _voices: Dictionary[Node, Dictionary] = {}
var _voice_order := 0

# event -> the GameEventListener that plays its cue
var _event_listeners: Dictionary = {}
# MenuSound -> the game's cue for it.
var _menu_cues: Dictionary[int, StringName] = {}
# The menu sound to play at the end of the frame; -1 for none.
var _pending_menu_sound := -1
# The frame the player last pressed one of `NAVIGATION_ACTIONS`.
var _navigated_frame := -1
# Whether the scene changed and its location's music is not known yet.
var _location_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_players()
	_connect_gameplay_events()
	_connect_menu_sounds()
	get_tree().scene_changed.connect(_on_scene_changed)
	_sync_location_music.call_deferred()

## Plays `cue_id`: a sound now, or music in the place of the location's.
## False when the content has no such cue or it has no stream yet.
func play_cue(cue_id: StringName) -> bool:
	var cue := _find_playable(cue_id)
	if cue == null:
		return false
	if cue.is_music():
		_set_base_music(cue.id)
		return true
	_start(_channel_for(cue, _sfx_players), cue)
	return true

## Plays the sound `cue_id` from `position` in the world (global), heard
## fainter the farther the view is; a music cue plays as music.
func play_cue_at(cue_id: StringName, position: Vector2) -> bool:
	var cue := _find_playable(cue_id)
	if cue == null:
		return false
	if cue.is_music():
		_set_base_music(cue.id)
		return true
	var player := _channel_for(cue, _positional_players) as AudioStreamPlayer2D
	player.global_position = position
	player.max_distance = cue.hearing_distance
	_start(player, cue)
	return true

## Plays the music `cue_id` over the music that plays until
## `pop_music(layer)`; `layer` names who pushed it (`&"fight"`). The newest
## pushed plays; pushing a layer again puts it on top with its new music.
func push_music(layer: StringName, cue_id: StringName) -> void:
	_remove_layer(layer)
	_pushed.append({"layer": layer, "cue_id": cue_id})
	_refresh_music(true)

## Takes away the music `layer` pushed; the music beneath comes back where it
## stopped.
func pop_music(layer: StringName) -> void:
	if _remove_layer(layer):
		_refresh_music(false)

## Whether `layer` pushed music that is not popped yet.
func has_pushed_music(layer: StringName) -> bool:
	return _pushed.any(func(entry: Dictionary) -> bool: return entry["layer"] == layer)

## Stops the music at once, the pushed included, until a location or a cue
## plays music again.
func stop_music() -> void:
	_pushed.clear()
	_resume_at.clear()
	_base_music_id = &""
	for player: AudioStreamPlayer in _music_players:
		_stop_fade(player)
		_silence(player)
	if _current_music_cue_id != &"":
		_current_music_cue_id = &""
		music_changed.emit(_current_music_cue_id)

func stop_all_sfx() -> void:
	for player: Node in _voices.keys():
		_silence(player)
	_voices.clear()

func get_current_music_cue_id() -> StringName:
	return _current_music_cue_id

## Plays the game's menu sound `sound` at the end of the frame, unless a more
## telling one is asked for in the same frame (`MenuSound`).
func play_menu_sound(sound: MenuSound) -> void:
	if _pending_menu_sound < 0:
		_play_menu_sound.call_deferred()
	_pending_menu_sound = maxi(_pending_menu_sound, sound)

func _build_players() -> void:
	for index in range(2):
		var music := AudioStreamPlayer.new()
		music.name = "Music%d" % index
		music.bus = &"Music"
		add_child(music)
		_music_players.append(music)
	for index in range(SFX_CHANNEL_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % index
		player.bus = &"Sounds"
		add_child(player)
		player.finished.connect(_on_channel_finished.bind(player))
		_sfx_players.append(player)
	for index in range(POSITIONAL_CHANNEL_COUNT):
		var positional := AudioStreamPlayer2D.new()
		positional.name = "Positional%d" % index
		positional.bus = &"Sounds"
		add_child(positional)
		positional.finished.connect(_on_channel_finished.bind(positional))
		_positional_players.append(positional)

## Plays the cue the game's `GameDefinition.event_cues` assigns to each event,
## a signal of an autoload named `<Autoload>.<signal>`
## (`LifesimEvents.crop_harvested`), whatever arguments the signal carries:
## from its `position`, when it carries one.
func _connect_gameplay_events() -> void:
	var event_cues := GameDefinition.current().event_cues
	for event: StringName in event_cues:
		var listener := GameEventListener.new(event, _play_event_cue.bind(event_cues[event]))
		if not listener.start():
			push_error("GameAudio: GameDefinition.event_cues names unknown event '%s'; name it <Autoload>.<signal>" % event)
			continue
		_event_listeners[event] = listener

func _play_event_cue(args: Dictionary, cue_id: StringName) -> void:
	var position: Variant = args.get("position")
	if position is Vector2:
		play_cue_at(cue_id, position)
	else:
		play_cue(cue_id)

func _connect_menu_sounds() -> void:
	var definition := GameDefinition.current()
	_menu_cues = {
		MenuSound.FOCUS: definition.menu_focus_cue_id,
		MenuSound.PRESS: definition.menu_press_cue_id,
		MenuSound.CLOSE: definition.menu_close_cue_id,
		MenuSound.OPEN: definition.menu_open_cue_id,
	}
	GameEvents.menu_opened.connect(func(_menu_id: StringName) -> void: play_menu_sound(MenuSound.OPEN))
	GameEvents.menu_closed.connect(func(_menu_id: StringName) -> void: play_menu_sound(MenuSound.CLOSE))
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _play_menu_sound() -> void:
	var sound := _pending_menu_sound
	_pending_menu_sound = -1
	play_cue(_menu_cues.get(sound, &""))

func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	play_menu_sound(MenuSound.PRESS)

func _input(event: InputEvent) -> void:
	for action: StringName in NAVIGATION_ACTIONS:
		if event.is_action_pressed(action, true):
			_navigated_frame = Engine.get_process_frames()
			return

func _on_focus_changed(_control: Control) -> void:
	# Only the focus the player moves sounds: a click sounds as pressed, and a
	# menu focusing its first control as opened.
	if _navigated_frame == Engine.get_process_frames():
		play_menu_sound(MenuSound.FOCUS)

# The cue `cue_id` when it can play; the request is announced either way.
func _find_playable(cue_id: StringName) -> AudioCueData:
	if cue_id == &"":
		return null
	cue_requested.emit(cue_id)
	var cue := AudioCueData.find(cue_id)
	return cue if cue != null and cue.stream != null else null

# A channel of `pool` for `cue`. A cue that plays its `max_voices` times
# already stops its oldest; then a quiet channel serves, else the one that
# has played longest.
func _channel_for(cue: AudioCueData, pool: Array) -> Node:
	var own: Array[Node] = []
	for player: Node in _voices:
		if _voices[player]["cue_id"] == cue.id:
			own.append(player)
	if own.size() >= cue.max_voices:
		var oldest := _oldest(own)
		if pool.has(oldest):
			return oldest
		_voices.erase(oldest)
		_silence(oldest)
	for player: Node in pool:
		if not _voices.has(player):
			return player
	return _oldest(pool)

func _oldest(players: Array) -> Node:
	var oldest: Node = null
	var oldest_order := 0
	for player: Node in players:
		var order := int(_voices.get(player, {}).get("order", 0))
		if oldest == null or order < oldest_order:
			oldest = player
			oldest_order = order
	return oldest

func _start(player: Node, cue: AudioCueData) -> void:
	player.call(&"stop")
	player.set(&"bus", cue.get_bus())
	player.set(&"stream", cue.stream)
	player.set(&"volume_db", cue.volume_db)
	player.set(&"pitch_scale", cue.get_pitch_scale())
	_voice_order += 1
	_voices[player] = {"cue_id": cue.id, "order": _voice_order}
	player.call(&"play")
	cue_started.emit(cue.id)

func _on_channel_finished(player: Node) -> void:
	_voices.erase(player)

func _silence(player: Node) -> void:
	player.call(&"stop")
	player.set(&"stream", null)

func _set_base_music(cue_id: StringName) -> void:
	if cue_id == _base_music_id:
		_refresh_music(false)
		return
	# Where the music beneath stopped is of no use once other music is beneath.
	_resume_at.erase(_base_music_id)
	_base_music_id = cue_id
	_refresh_music(false)

func _remove_layer(layer: StringName) -> bool:
	for index in range(_pushed.size() - 1, -1, -1):
		if _pushed[index]["layer"] == layer:
			var cue_id: StringName = _pushed[index]["cue_id"]
			_pushed.remove_at(index)
			# Where its music stopped is of no use once nothing plays it.
			if cue_id != _base_music_id and not _pushed.any(func(entry: Dictionary) -> bool: return entry["cue_id"] == cue_id):
				_resume_at.erase(cue_id)
			return true
	return false

# Plays the music that should play: the newest pushed, else the base. A
# change for music pushed over (`covered`) keeps where the music it covers
# stopped, for when it comes back. Until a new scene's location is known,
# the music beneath stays as it is.
func _refresh_music(covered: bool) -> void:
	if _location_pending and _pushed.is_empty():
		return
	var cue_id := StringName(_pushed.back()["cue_id"]) if not _pushed.is_empty() else _base_music_id
	var cue := AudioCueData.find(cue_id) if cue_id != &"" else null
	if cue != null and (cue.stream == null or not cue.is_music()):
		cue = null
	var next_id := cue.id if cue != null else &""
	if next_id == _current_music_cue_id:
		return
	var current := _music_players[_music_index]
	var fade := cue.fade_seconds if cue != null else _current_fade_seconds()
	if _current_music_cue_id != &"":
		if covered:
			_resume_at[_current_music_cue_id] = current.get_playback_position()
		_fade(current, 0.0, fade, true)
	_current_music_cue_id = next_id
	if cue != null:
		_music_index = 1 - _music_index
		var player := _music_players[_music_index]
		_stop_fade(player)
		player.stream = cue.stream
		player.pitch_scale = cue.get_pitch_scale()
		var volume := db_to_linear(cue.volume_db)
		player.volume_linear = 0.0 if fade > 0.0 else volume
		player.play(_resume_at.get(cue.id, 0.0))
		_resume_at.erase(cue.id)
		_fade(player, volume, fade, false)
		cue_started.emit(cue.id)
	music_changed.emit(_current_music_cue_id)

func _current_fade_seconds() -> float:
	var current := AudioCueData.find(_current_music_cue_id) if _current_music_cue_id != &"" else null
	return current.fade_seconds if current != null else 0.0

# Takes `player` to `volume` (linear) over `seconds`, then stops it when
# `then_stop`.
func _fade(player: AudioStreamPlayer, volume: float, seconds: float, then_stop: bool) -> void:
	_stop_fade(player)
	if seconds <= 0.0:
		player.volume_linear = volume
		if then_stop:
			_silence(player)
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_linear", volume, seconds)
	if then_stop:
		tween.tween_callback(_silence.bind(player))
	_music_fades[player] = tween

func _stop_fade(player: AudioStreamPlayer) -> void:
	var tween: Tween = _music_fades.get(player)
	if tween != null and tween.is_valid():
		tween.kill()
	_music_fades.erase(player)

func _on_scene_changed() -> void:
	_location_pending = true
	_sync_location_music.call_deferred()

func _sync_location_music() -> void:
	await get_tree().process_frame
	_location_pending = false
	var location := WorldLocationData.find_current(get_tree())
	_set_base_music(location.music_cue_id if location != null else &"")
