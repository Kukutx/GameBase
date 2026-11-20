class_name MiniGameDefinition
extends ContentEntry

## A minigame the game can start through `MiniGameHost.run()`: from a
## station in the world (`MiniGameStation`), which can offer several for the
## player to pick from, such as a campaign's battles, each open once its
## `condition` holds.

const KIND := &"minigame"

## The name the player picks it by at a station that offers several.
@export var display_name := ""
## A line under the name there.
@export_multiline var description := ""
## What must hold for the player to pick it there (`GameRules` syntax; empty:
## always): `MINIGAME_WON ford_battle` opens a battle once the one before it
## is won. A locked one says what it needs (`GameRules.describe()`).
@export var condition := ""
## What its score counts, in words the player reads ("Units Left"): the list
## of a station shows the player's best score under it once they have one.
## Empty: the score shows nowhere. The best score stays in the player's
## profile, across saves (`get_best_score()`), so a record can show it
## (`RecordData.flag`, `best_score_key()`).
@export var score_name := ""

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

## The key of the world state's count of the player's wins of minigame
## `minigame_id` in this save, which `MiniGameHost` counts.
static func wins_key(minigame_id: StringName) -> StringName:
	return StringName("minigame:%s:wins" % minigame_id)

## How many times the player won it in this save.
func get_wins() -> int:
	return WorldState.get_int(wins_key(id))

## The key of the profile's best score of minigame `minigame_id`, in any
## save, which `MiniGameHost` keeps.
static func best_score_key(minigame_id: StringName) -> StringName:
	return StringName("minigame:%s:best" % minigame_id)

## The player's best score of it in any save; 0 before they have one.
func get_best_score() -> int:
	return GameProfile.get_int(best_score_key(id))

## Whether the player can pick it at a station: its condition holds.
func is_open() -> bool:
	return GameRules.check(condition)

## What it needs before the player can pick it, in words they read.
func get_requirements() -> PackedStringArray:
	return GameRules.describe(condition)

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
