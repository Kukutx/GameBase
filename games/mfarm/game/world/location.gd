class_name MFarmLocation
extends Node2D

## The root of an MFarm location's scene: names the location its nodes belong
## to and plays its ambient sound under the location's music, over and over,
## at the old mixer's levels. It is heard alone, fading in over a second,
## while the place's music waits (the old "Ambient Only" snapshot), and goes
## 10 dB down as the music comes in over eight seconds ("Normal").

const AMBIENT_FADE_SECONDS := 1.0
## The old mixer's ambience, alone and under the music, and how long the old
## music took to come in.
const AMBIENT_ALONE_DB := -0.17
const AMBIENT_UNDER_MUSIC_DB := -10.35
const MUSIC_FADE_SECONDS := 8.0

@export var location_id: StringName
@export var ambient: AudioStream

var _ambient: AudioStreamPlayer
var _fade: Tween

func _ready() -> void:
	add_to_group(&"mfarm_location")
	if ambient == null:
		return
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "Ambient"
	_ambient.stream = ambient
	_ambient.volume_linear = 0.0
	_ambient.bus = &"Sounds"
	add_child(_ambient)
	# The imported stream does not loop; the old game's ambient source did.
	_ambient.finished.connect(_ambient.play)
	_ambient.play()
	GameAudio.music_changed.connect(_on_music_changed)
	_fade_ambient(GameAudio.get_current_music_cue_id() != &"", AMBIENT_FADE_SECONDS)

## The level the ambient sound is at, or fading to: under the music or alone.
func get_ambient_target_db() -> float:
	return AMBIENT_UNDER_MUSIC_DB if GameAudio.get_current_music_cue_id() != &"" else AMBIENT_ALONE_DB

func _on_music_changed(cue_id: StringName) -> void:
	_fade_ambient(cue_id != &"", MUSIC_FADE_SECONDS if cue_id != &"" else AMBIENT_FADE_SECONDS)

func _fade_ambient(under_music: bool, seconds: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_ambient, ^"volume_linear", db_to_linear(AMBIENT_UNDER_MUSIC_DB if under_music else AMBIENT_ALONE_DB), seconds)

## The id of the location whose scene holds `node`, or empty.
static func id_of(node: Node) -> StringName:
	var current := node
	while current != null:
		if current is MFarmLocation:
			return (current as MFarmLocation).location_id
		current = current.get_parent()
	return &""

## A key naming `node` within its location's scene, stable across loads.
static func key_of(node: Node) -> String:
	var current := node
	while current != null and not current is MFarmLocation:
		current = current.get_parent()
	return String(current.get_path_to(node)) if current != null else String(node.name)
