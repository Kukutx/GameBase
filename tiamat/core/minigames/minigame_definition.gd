class_name MiniGameDefinition
extends ContentEntry

## A minigame the game can start through `MiniGameHost.run()`.

const KIND := &"minigame"

## Scene whose root extends `MiniGame`.
@export var scene: PackedScene
## Pauses the world (clock, actors, other menus) while the minigame runs.
@export var pause_world := true
## Actions (`GameRules` syntax) run when the player wins or loses.
@export var success_actions: PackedStringArray = PackedStringArray()
@export var failure_actions: PackedStringArray = PackedStringArray()
## The music it plays over the world's while it runs (`GameAudio.push_music()`);
## empty: the world's plays on.
@export var music_cue_id: StringName = &""
## Tuning passed to the minigame's `setup()`; the caller's context overrides it.
## The minigame checks it (`MiniGame.find_settings_problems()`).
@export var settings: Dictionary = {}

## The minigame with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> MiniGameDefinition:
	return ContentRegistry.active.get_entry(KIND, entry_id) as MiniGameDefinition

## The running game's minigames, sorted by id.
static func find_all() -> Array[MiniGameDefinition]:
	var result: Array[MiniGameDefinition] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := AudioCueData.find_reference_problems(registry, "its music", music_cue_id, AudioCueData.CueType.MUSIC)
	if scene == null:
		problems.append("has no scene")
		return problems
	var root := scene.instantiate()
	var minigame := root as MiniGame
	if minigame == null:
		problems.append("scene root does not extend MiniGame")
	else:
		problems.append_array(minigame.find_settings_problems(settings, registry))
	if root != null:
		root.free()
	return problems
