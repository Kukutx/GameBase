class_name FightService
extends Node

## Whether the player is in a fight: a hostile creature hunts them
## (`HostileCreature`, chasing them or stunned by their hit). The fight starts
## with the first hunter (`CombatEvents.fight_started`) and ends
## (`CombatEvents.fight_ended`) `CombatSettings.fight_calm_seconds` after the
## last one gave up or fell, and at once when the player leaves for another
## scene or is taken out of play (`end_fight()`, which
## `GameSession.end_activities()` calls).
## While it lasts, the game's fight music (`CombatSettings.fight_music_cue_id`)
## plays over the location's (`GameAudio.push_music()`, layer `MUSIC_LAYER`),
## which then comes back where it stopped. The calm waits while the world is
## paused. The service saves nothing.

## The music layer a fight's music plays on.
const MUSIC_LAYER := &"fight"

# The instance ids of the creatures that hunt the player.
var _hunters: Dictionary[int, bool] = {}
var _fighting := false
var _calm_left := 0.0

func _ready() -> void:
	set_process(false)
	get_tree().scene_changed.connect(_on_scene_changed)

## Whether a fight is on.
func is_fighting() -> bool:
	return _fighting

## How many creatures hunt the player.
func get_hunter_count() -> int:
	return _hunters.size()

## `hunter` hunts the player, or no longer does (it gave up, fell or left).
func set_hunting(hunter: Node, hunting: bool) -> void:
	var id := hunter.get_instance_id()
	if hunting:
		_hunters[id] = true
		set_process(false)
		if not _fighting:
			_start()
	elif _hunters.erase(id) and _hunters.is_empty() and _fighting:
		_calm_left = CombatSettings.current().fight_calm_seconds
		if _calm_left > 0.0:
			set_process(true)
		else:
			_end()

## Ends the fight at once and forgets its hunters.
func end_fight() -> void:
	_hunters.clear()
	set_process(false)
	if _fighting:
		_end()

func _process(delta: float) -> void:
	_calm_left -= delta
	if _calm_left <= 0.0:
		set_process(false)
		_end()

# The hunters of the scene before left with it.
func _on_scene_changed() -> void:
	if _fighting and _hunters.is_empty():
		set_process(false)
		_end()

func _start() -> void:
	_fighting = true
	var music := CombatSettings.current().fight_music_cue_id
	if music != &"":
		GameAudio.push_music(MUSIC_LAYER, music)
	CombatEvents.fight_started.emit()

func _end() -> void:
	_fighting = false
	GameAudio.pop_music(MUSIC_LAYER)
	CombatEvents.fight_ended.emit()
