class_name GameContentDatabase
extends ContentRegistry

## This game's content. Register every kind of content the game has, including
## the foundation's own kinds (locations, audio cues, minigames).

const MANIFEST := preload("res://game/content/content_manifest.tres")

func _index_content(errors: PackedStringArray) -> bool:
	register_entries(KIND_LOCATION, MANIFEST.locations, "location", errors)
	register_entries(KIND_AUDIO_CUE, MANIFEST.audio_cues, "audio cue", errors)
	register_entries(KIND_MINIGAME, MANIFEST.minigames, "minigame", errors)
	return true
