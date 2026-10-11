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
## Tuning passed to the minigame's `setup()`; the caller's context overrides it.
@export var settings: Dictionary = {}

## The minigame with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> MiniGameDefinition:
	return ContentRegistry.active.get_entry(KIND, entry_id) as MiniGameDefinition

## The running game's minigames, sorted by id.
static func find_all() -> Array[MiniGameDefinition]:
	var result: Array[MiniGameDefinition] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	if scene == null:
		return PackedStringArray(["has no scene"])
	var root := scene.instantiate()
	var is_minigame := root is MiniGame
	if root != null:
		root.free()
	return PackedStringArray() if is_minigame else PackedStringArray(["scene root does not extend MiniGame"])
