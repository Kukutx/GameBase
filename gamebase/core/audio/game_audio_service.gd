class_name GameAudioService
extends Node

signal cue_requested(cue_id: StringName)
signal cue_started(cue_id: StringName)
signal music_changed(cue_id: StringName)

const SFX_CHANNEL_COUNT := 8

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _current_music_cue_id: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_players()
	_connect_gameplay_events()
	get_tree().scene_changed.connect(_on_scene_changed)
	_sync_location_music.call_deferred()

func play_cue(cue_id: StringName) -> bool:
	if cue_id == &"":
		return false
	cue_requested.emit(cue_id)
	var cue := ContentDB.get_audio_cue(cue_id)
	if cue == null or cue.stream == null:
		return false
	if cue.is_music():
		return _play_music(cue)
	return _play_sfx(cue)

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	if _current_music_cue_id != &"":
		_current_music_cue_id = &""
		music_changed.emit(_current_music_cue_id)

func stop_all_sfx() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()
		player.stream = null

func get_current_music_cue_id() -> StringName:
	return _current_music_cue_id

func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	add_child(_music_player)

	for index in range(SFX_CHANNEL_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % index
		player.bus = &"Sounds"
		add_child(player)
		_sfx_players.append(player)

## Plays the cue the game's `GameDefinition.event_cues` assigns to each
## `GameEvents` signal, whatever arguments the signal carries.
func _connect_gameplay_events() -> void:
	var argument_counts: Dictionary = {}
	for info: Dictionary in GameEvents.get_signal_list():
		argument_counts[StringName(info["name"])] = (info["args"] as Array).size()
	for signal_name: StringName in GameSession.definition.event_cues:
		if not argument_counts.has(signal_name):
			push_error("GameAudio: GameDefinition.event_cues names unknown GameEvents signal '%s'" % signal_name)
			continue
		var cue_id: StringName = GameSession.definition.event_cues[signal_name]
		GameEvents.connect(signal_name, play_cue.bind(cue_id).unbind(int(argument_counts[signal_name])))

func _play_music(cue: AudioCueData) -> bool:
	if _music_player == null:
		return false
	if _current_music_cue_id == cue.id and _music_player.stream == cue.stream and _music_player.playing:
		return true
	_music_player.stop()
	_music_player.bus = cue.get_bus()
	_music_player.stream = cue.stream
	_music_player.volume_db = cue.volume_db
	_music_player.pitch_scale = cue.get_pitch_scale()
	_current_music_cue_id = cue.id
	_music_player.play()
	cue_started.emit(cue.id)
	music_changed.emit(cue.id)
	return true

func _play_sfx(cue: AudioCueData) -> bool:
	if _sfx_players.is_empty():
		return false
	var player := _sfx_players[_sfx_cursor % _sfx_players.size()]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.bus = cue.get_bus()
	player.stream = cue.stream
	player.volume_db = cue.volume_db
	player.pitch_scale = cue.get_pitch_scale()
	player.play()
	cue_started.emit(cue.id)
	return true

func _on_scene_changed() -> void:
	_sync_location_music.call_deferred()

func _sync_location_music() -> void:
	await get_tree().process_frame
	var location := ContentDB.get_current_location(get_tree())
	if location == null or location.music_cue_id == &"":
		stop_music()
		return
	var cue := ContentDB.get_audio_cue(location.music_cue_id)
	if cue == null or cue.stream == null:
		stop_music()
		return
	play_cue(location.music_cue_id)
