class_name AudioCueData
extends ContentEntry

enum CueType {
	SFX,
	MUSIC,
}

@export var cue_type: CueType = CueType.SFX
@export var stream: AudioStream
@export_range(-60.0, 12.0, 0.1) var volume_db := 0.0
@export_range(0.5, 2.0, 0.01) var pitch_min := 1.0
@export_range(0.5, 2.0, 0.01) var pitch_max := 1.0

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
