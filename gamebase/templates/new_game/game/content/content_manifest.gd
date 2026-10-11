class_name ContentManifest
extends Resource

## Every content entry of this game, by kind.

@export var locations: Array[WorldLocationData] = []
@export var audio_cues: Array[AudioCueData] = []
@export var minigames: Array[MiniGameDefinition] = []
