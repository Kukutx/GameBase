class_name AudioCueData
extends ContentEntry

## A sound or a piece of music the game plays by its id (`GameAudio`). A cue
## without a stream is a slot waiting for its audio, and plays nothing.

enum CueType {
	SFX,
	MUSIC,
}

const KIND := &"audio_cue"

@export var cue_type: CueType = CueType.SFX
@export var stream: AudioStream
@export_range(-60.0, 12.0, 0.1) var volume_db := 0.0
@export_range(0.5, 2.0, 0.01) var pitch_min := 1.0
@export_range(0.5, 2.0, 0.01) var pitch_max := 1.0
## Music: how long it takes to fade in, and the music before it to fade out.
@export_range(0.0, 10.0, 0.05) var fade_seconds := 1.0
## Sounds: how many of the cue play at once at most; one more stops the
## oldest of them.
@export_range(1, 8) var max_voices := 3
## Sounds played at a place in the world: how far from the view's centre they
## are still heard, in pixels.
@export_range(16.0, 4000.0, 1.0) var hearing_distance := 640.0

## The audio cue with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> AudioCueData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as AudioCueData

## The running game's audio cues, sorted by id.
static func find_all() -> Array[AudioCueData]:
	var result: Array[AudioCueData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func is_music() -> bool:
	return cue_type == CueType.MUSIC

func get_bus() -> StringName:
	return &"Music" if is_music() else &"Sounds"

func get_pitch_scale() -> float:
	var low := minf(pitch_min, pitch_max)
	var high := maxf(pitch_min, pitch_max)
	if is_equal_approx(low, high):
		return maxf(low, 0.01)
	return maxf(randf_range(low, high), 0.01)

## Problems with `cue_id`, which `what` names as a cue of type `wanted`: no
## such cue in `registry`, or a cue of the other type. None for an empty id.
static func find_reference_problems(registry: ContentRegistry, what: String, cue_id: StringName, wanted: CueType) -> PackedStringArray:
	if cue_id == &"":
		return PackedStringArray()
	var cue := registry.get_entry(KIND, cue_id) as AudioCueData
	if cue == null:
		return PackedStringArray(["%s names unknown audio cue '%s'" % [what, cue_id]])
	if cue.cue_type != wanted:
		return PackedStringArray(["%s names audio cue '%s', which is no %s" % [what, cue_id, "music" if wanted == CueType.MUSIC else "sound"]])
	return PackedStringArray()

## Problems with the cues the game's definition names: each event of
## `GameDefinition.event_cues` must be a signal of an autoload, and its cue and
## each menu sound's a sound of the content.
static func find_definition_problems(definition: GameDefinition, registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for event: StringName in definition.event_cues:
		if GameEvent.find_source(event) == null:
			problems.append("the event cues name '%s', which is no signal of an autoload (<Autoload>.<signal>)" % event)
		problems.append_array(find_reference_problems(registry, "the cue of event %s" % event, definition.event_cues[event], CueType.SFX))
	var menu_cues := {
		"menu focus": definition.menu_focus_cue_id,
		"menu press": definition.menu_press_cue_id,
		"menu open": definition.menu_open_cue_id,
		"menu close": definition.menu_close_cue_id,
	}
	for sound: String in menu_cues:
		problems.append_array(find_reference_problems(registry, "the %s sound" % sound, menu_cues[sound], CueType.SFX))
	return problems

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not CueType.values().has(cue_type):
		problems.append("has invalid cue type %d" % cue_type)
	if pitch_min <= 0.0 or pitch_max <= 0.0:
		problems.append("has non-positive pitch range")
	if pitch_min > pitch_max:
		problems.append("has inverted pitch range")
	if fade_seconds < 0.0:
		problems.append("has a negative fade")
	if max_voices < 1:
		problems.append("plays at most %d at once" % max_voices)
	if hearing_distance <= 0.0:
		problems.append("is heard from no distance")
	return problems
