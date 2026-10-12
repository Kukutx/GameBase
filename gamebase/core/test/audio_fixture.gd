extends RefCounted

## Audio for a test of the foundation, which ships none: cues the test builds
## (`AudioCueData`) on silent streams in memory, and what `GameAudio`'s
## channels hold.
##
##     const AudioFixture := preload("res://gamebase/core/test/audio_fixture.gd")

## A cue `id` of `cue_type` on `stream` (none: a slot waiting for its audio),
## fading at once.
static func cue(id: StringName, cue_type: AudioCueData.CueType, stream: AudioStream = null) -> AudioCueData:
	var made := AudioCueData.new()
	made.id = id
	made.cue_type = cue_type
	made.stream = stream
	made.fade_seconds = 0.0
	return made

## A silent 8-bit stream `seconds` long.
static func stream(seconds := 0.01) -> AudioStreamWAV:
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_8_BITS
	made.mix_rate = 8000
	made.stereo = false
	var data := PackedByteArray()
	data.resize(maxi(int(seconds * 8000.0), 8))
	data.fill(128)
	made.data = data
	return made

## The channels of `service` (players of its sounds or its music) that hold
## `stream`.
static func players_of(service: Node, stream: AudioStream) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in service.get_children():
		if (child is AudioStreamPlayer or child is AudioStreamPlayer2D) and child.get(&"stream") == stream:
			found.append(child)
	return found
