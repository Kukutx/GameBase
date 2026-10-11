class_name WorldLocationData
extends ContentEntry

enum LocationType {
	TOWN,
	INTERIOR,
	WILDERNESS,
	DUNGEON,
}

const KIND := &"location"

@export var display_name: String
@export_file("*.tscn") var scene_path: String
@export var type: LocationType = LocationType.TOWN
@export var weather_exposed := true
@export var default_spawn_id: StringName
@export var music_cue_id: StringName

## The location with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> WorldLocationData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as WorldLocationData

## The running game's locations, sorted by id.
static func find_all() -> Array[WorldLocationData]:
	var result: Array[WorldLocationData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	if music_cue_id == &"":
		return PackedStringArray()
	var cue := registry.get_entry(AudioCueData.KIND, music_cue_id) as AudioCueData
	if cue == null:
		return PackedStringArray(["references unknown music cue '%s'" % music_cue_id])
	if not cue.is_music():
		return PackedStringArray(["music cue '%s' is not MUSIC" % music_cue_id])
	return PackedStringArray()
