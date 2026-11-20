class_name WorldLocationData
extends ContentEntry

## A place of the world the player can be in: its scene, where travel puts the
## player in it (its `WorldSpawnPoint` nodes, `WorldTravelService`), the music
## that plays there, whether the weather reaches it and the region it belongs
## to. The game starts and wakes the player in locations of its own
## (`GameDefinition`), and portals (`InteractivePortal`) lead between them.

## What kind of place it is; a placeable may be built only in some kinds
## (`PlaceableData.allowed_location_types`).
enum LocationType {
	TOWN,
	INTERIOR,
	WILDERNESS,
	DUNGEON,
}

const KIND := &"location"

## The name the player reads.
@export var display_name: String
## The scene of the place; validation opens it to check its spawn points,
## portals and the content its nodes name.
@export_file("*.tscn") var scene_path: String
## What kind of place it is: what may be built there
## (`PlaceableData.allowed_location_types`), and what a game's menus call it.
@export var type: LocationType = LocationType.TOWN
## Whether the weather shows here (`WeatherOverlay`); off for a place indoors.
@export var weather_exposed := true
## The spawn point (`WorldSpawnPoint.spawn_id`) travel puts the player at when
## it names none; the scene must have it.
@export var default_spawn_id: StringName
## The music (`AudioCueData`, a `MUSIC` cue) that plays while the player is
## here; empty, silence.
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
