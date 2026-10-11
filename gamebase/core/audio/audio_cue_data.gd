class_name AudioCueData
extends ContentEntry

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

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not CueType.values().has(cue_type):
		problems.append("has invalid cue type %d" % cue_type)
	if pitch_min <= 0.0 or pitch_max <= 0.0:
		problems.append("has non-positive pitch range")
	if pitch_min > pitch_max:
		problems.append("has inverted pitch range")
	return problems
