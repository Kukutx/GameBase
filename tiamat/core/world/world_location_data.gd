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
## The region the location belongs to (`RegionData`); empty for none.
@export var region_id: StringName

## The location with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> WorldLocationData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as WorldLocationData

## The running game's locations, sorted by id.
static func find_all() -> Array[WorldLocationData]:
	var result: Array[WorldLocationData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## The location whose scene is `scene_path` in the running game's content, or
## null.
static func find_for_scene(scene_path: String) -> WorldLocationData:
	return ContentRegistry.active.get_location_for_scene(scene_path)

## The location whose scene is `tree`'s current scene, or null.
static func find_current(tree: SceneTree) -> WorldLocationData:
	if tree == null or tree.current_scene == null:
		return null
	return find_for_scene(tree.current_scene.scene_file_path)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if region_id != &"" and not registry.has_entry(RegionData.KIND, region_id):
		problems.append("belongs to unknown region '%s'" % region_id)
	if music_cue_id == &"":
		return problems
	var cue := registry.get_entry(AudioCueData.KIND, music_cue_id) as AudioCueData
	if cue == null:
		problems.append("references unknown music cue '%s'" % music_cue_id)
	elif not cue.is_music():
		problems.append("music cue '%s' is not MUSIC" % music_cue_id)
	return problems
