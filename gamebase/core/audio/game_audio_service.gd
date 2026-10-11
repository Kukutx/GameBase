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
	var cue := AudioCueData.find(cue_id)
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

## Plays the cue the game's `GameDefinition.event_cues` assigns to each event,
## a signal of an autoload named `<Autoload>.<signal>`
## (`LifesimEvents.crop_harvested`), whatever arguments the signal carries.
func _connect_gameplay_events() -> void:
	for event: StringName in GameSession.definition.event_cues:
		var parts := String(event).split(".")
		var source: Node = get_tree().root.get_node_or_null(NodePath(parts[0])) if parts.size() == 2 else null
		var argument_count := -1
		if source != null:
			for info: Dictionary in source.get_signal_list():
				if info["name"] == parts[1]:
					argument_count = (info["args"] as Array).size()
		if argument_count < 0:
			push_error("GameAudio: GameDefinition.event_cues names unknown event '%s'; name it <Autoload>.<signal>" % event)
			continue
		var cue_id: StringName = GameSession.definition.event_cues[event]
		source.connect(parts[1], play_cue.bind(cue_id).unbind(argument_count))

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
	var cue := AudioCueData.find(location.music_cue_id)
	if cue == null or cue.stream == null:
		stop_music()
		return
	play_cue(location.music_cue_id)
