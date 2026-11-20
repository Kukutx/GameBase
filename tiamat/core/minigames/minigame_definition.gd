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
## The scores the player aims for, lowest first, each above the one before
## (Units Left 2, 3, 4): each one their best score reaches is a star, which
## the list of a station and the pause menu's Challenges show (★★☆) with the
## score the next star needs, and which `MINIGAME_STARS` counts. Needs a
## `score_name`; empty: no stars.
@export var score_goals: PackedInt32Array = PackedInt32Array()

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

## The stars the player's best score has earned (`score_goals`).
func get_stars() -> int:
	return stars_for(get_best_score())

## The stars a best score of `score` earns.
func stars_for(score: int) -> int:
	var stars := 0
	for goal: int in score_goals:
		if score >= goal:
			stars += 1
	return stars

## The score the player's next star needs, or 0 once they have every star
## (or it has none).
func get_next_goal() -> int:
	for goal: int in score_goals:
		if get_best_score() < goal:
			return goal
	return 0

## The stars earned and those still to earn, as the player sees them: "★★☆";
## empty without `score_goals`.
func describe_stars() -> String:
	var stars := get_stars()
	return "★".repeat(stars) + "☆".repeat(score_goals.size() - stars)

## The player's best score and stars, in lines they read ("Best Units Left: 3",
## "★★☆ · Next star: Units Left 4"); nothing without a `score_name`.
func describe_score() -> PackedStringArray:
	var lines := PackedStringArray()
	if score_name.is_empty():
		return lines
	var score_title := String(TranslationServer.translate(score_name))
	if get_best_score() > 0:
		lines.append(TranslationServer.translate("Best %s: %d") % [score_title, get_best_score()])
	if score_goals.is_empty():
		return lines
	var next := get_next_goal()
	lines.append(describe_stars() if next == 0 else TranslationServer.translate("%s · Next star: %s %d") % [describe_stars(), score_title, next])
	return lines

## The pause menu's Challenges: how many of the minigames the player picks by
## name at a station (`display_name`) they have won in this save, and how
## many of their stars they have, then each, those open first, with its wins,
## best score and stars, or what it needs while it is locked; nothing in a
## game without any.
static func describe_challenges() -> PackedStringArray:
	var lines := PackedStringArray()
	var named: Array[MiniGameDefinition] = []
	named.assign(find_all().filter(func(minigame: MiniGameDefinition) -> bool: return not minigame.display_name.is_empty()))
	if named.is_empty():
		return lines
	var won := named.filter(func(minigame: MiniGameDefinition) -> bool: return minigame.get_wins() > 0)
	lines.append(TranslationServer.translate("Won %d of %d") % [won.size(), named.size()])
	var stars := 0
	var all_stars := 0
	for minigame: MiniGameDefinition in named:
		stars += minigame.get_stars()
		all_stars += minigame.score_goals.size()
	if all_stars > 0:
		lines.append(TranslationServer.translate("Stars %d of %d") % [stars, all_stars])
	for open: bool in [true, false]:
		for minigame: MiniGameDefinition in named:
			if minigame.is_open() == open:
				lines.append_array(minigame.describe_progress())
	return lines

## How far the player is with it, in lines they read: its wins in this save,
## its best score and stars, or what it needs while it is locked.
func describe_progress() -> PackedStringArray:
	var title := String(TranslationServer.translate(display_name))
	if not is_open():
		var needs := get_requirements()
		if needs.is_empty():
			return PackedStringArray([TranslationServer.translate("%s — locked") % title])
		return PackedStringArray([TranslationServer.translate("%s — needs %s") % [title, ", ".join(needs)]])
	var wins := get_wins()
	var lines := PackedStringArray([TranslationServer.translate("%s — won %d") % [title, wins] if wins > 0 else TranslationServer.translate("%s — not won yet") % title])
	for line: String in describe_score():
		lines.append("  " + line)
	return lines

## Whether the player can pick it at a station: its condition holds.
func is_open() -> bool:
	return GameRules.check(condition)

## What it needs before the player can pick it, in words they read.
func get_requirements() -> PackedStringArray:
	return GameRules.describe(condition)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := AudioCueData.find_reference_problems(registry, "its music", music_cue_id, AudioCueData.CueType.MUSIC)
	if not score_goals.is_empty() and score_name.is_empty():
		problems.append("has score goals but no score name")
	for index: int in score_goals.size():
		if score_goals[index] <= (score_goals[index - 1] if index > 0 else 0):
			problems.append("score goals must be above 0, each above the one before: %s" % [Array(score_goals)])
			break
	if scene == null:
		problems.append("has no scene")
		return problems
	var root := scene.instantiate()
	var minigame := root as MiniGame
	if minigame == null:
		problems.append("scene root does not extend MiniGame")
	else:
		problems.append_array(minigame.find_settings_problems(settings, registry))
		var best := minigame.get_best_possible_score(settings, registry)
		if not score_goals.is_empty() and best >= 0 and score_goals[-1] > best:
			problems.append("asks for a score of %d, but %d is the most it can give" % [score_goals[-1], best])
	if root != null:
		root.free()
	return problems
