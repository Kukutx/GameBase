class_name PlaythroughService
extends Node

## The playthrough: the first, or a later one that carries part of the one
## before it over (new game plus). What carries over is the game's
## `GameDefinition.inheritance`, each an `InheritanceRule` (a share of the
## money, the items with a tag, the skills' experience): when the player starts
## the next playthrough (`start_next()`) each rule takes its part of the game
## as it is, and the new game the session then starts gives it back once its
## services are reset. The playthrough's number saves with the game, and
## content asks for it with `PLAYTHROUGH_AT_LEAST`.
##
## A sequel carries a game over the same way: the game writes its legacy
## (`write_legacy()`: what its rules take, by rule key), and the sequel starts
## a new game from it (`start_from_legacy()`), each of its rules reading the
## part with its own key. `find_legacy()` reads the legacy another game wrote
## on this device.
##
## The new game knows its playthrough from its first step on, and gets what
## carries over once the services and the start items are reset, before the
## quests start (they measure what the player has). A game step that resets
## state runs before `NEW_GAME_ORDER_CARRY`.

## A new game was set up as playthrough `playthrough`, with what carried over.
## It fires while the session changes, so content follows the playthrough with
## `PLAYTHROUGH_AT_LEAST` rather than with this signal.
signal playthrough_started(playthrough: int)

const SAVE_SECTION := &"playthrough"
## The new game's playthrough is known before anything else is set up.
const NEW_GAME_ORDER_NUMBER := 60
## What carries over is given back after the services reset and the start
## items (`items` 1300), before the quests start (`progression` 1400).
const NEW_GAME_ORDER_CARRY := 1350
## The layout of a legacy file; a file of another version is not read.
const LEGACY_VERSION := 1
const LEGACY_FILE := "legacy.json"

## Where `write_legacy()` writes.
var legacy_path := "user://" + LEGACY_FILE

var _playthrough := 1
# What the next new game starts as: {"playthrough": int, "carried": rule key -> part}.
var _next: Dictionary = {}

func _ready() -> void:
	SaveManager.register_section(SaveSection.new(SAVE_SECTION, GameSaveManager.SECTION_ORDER_PLAYTHROUGH, _to_save_data, _load_save_data))
	GameSession.register_new_game_step(&"playthrough_number", NEW_GAME_ORDER_NUMBER, _begin)
	GameSession.register_new_game_step(&"playthrough_carry", NEW_GAME_ORDER_CARRY, _carry_over)

## The running game's playthrough: 1 for the first.
func get_playthrough() -> int:
	return _playthrough

## What each of the game's rules takes of the game as it is, by rule key.
func capture() -> Dictionary:
	var carried: Dictionary = {}
	for rule: InheritanceRule in GameDefinition.current().inheritance:
		if rule != null and rule.key != &"":
			carried[String(rule.key)] = rule.capture()
	return carried

## Starts the next playthrough in the selected slot: what the rules take of the
## game as it is carries over into a new game (`GameSession.start_new_game()`,
## which also ends what the player was doing). False when the new game cannot
## start.
func start_next() -> bool:
	return _start(_playthrough + 1, capture())

## Starts a new game in the selected slot from `legacy`, a game's legacy
## (`read_legacy()`): each rule gets the part with its key. It is the first
## playthrough of this game. False when the new game cannot start.
func start_from_legacy(legacy: Dictionary) -> bool:
	var carried: Variant = legacy.get("carried", {})
	return _start(1, carried if carried is Dictionary else {})

## The running game's legacy, what a sequel carries over:
## {"version", "game" (its `application/config/name`), "playthrough", "carried"}.
func make_legacy() -> Dictionary:
	return {
		"version": LEGACY_VERSION,
		"game": String(ProjectSettings.get_setting("application/config/name", "")),
		"playthrough": _playthrough,
		"carried": capture(),
	}

## Writes the running game's legacy to `legacy_path`, where a sequel on this
## device finds it (`find_legacy()`). False when it could not be written.
func write_legacy() -> bool:
	var problem := JsonFile.write(legacy_path, make_legacy())
	if not problem.is_empty():
		push_warning("Playthrough: %s" % problem)
	return problem.is_empty()

## The legacy in the file at `path`; empty when there is none, it cannot be
## read or it has another layout.
static func read_legacy(path: String) -> Dictionary:
	var parsed: Variant = JsonFile.read(path)
	if not parsed is Dictionary:
		return {}
	var legacy: Dictionary = parsed
	if SaveValues.whole_number_or(legacy.get("version"), -1) != LEGACY_VERSION or not legacy.get("carried") is Dictionary:
		return {}
	return legacy

## The legacy the game named `application_name` (its `application/config/name`)
## wrote on this device; empty when there is none. Games find each other's
## files when neither sets a custom user directory and the platform lets one
## game read another's (not a sandboxed or web build).
static func find_legacy(application_name: String) -> Dictionary:
	return read_legacy(OS.get_user_data_dir().get_base_dir().path_join(user_directory_name(application_name)).path_join(LEGACY_FILE))

## The name of the user directory of the game named `application_name`, as the
## engine makes it: trimmed, what a directory name cannot hold replaced with
## "-", and no periods at its end.
static func user_directory_name(application_name: String) -> String:
	var name := application_name.strip_edges()
	for character: String in [":", "*", "?", "\"", "<", ">", "|", "/", "\\"]:
		name = name.replace(character, "-")
	while name.ends_with("."):
		name = name.left(-1)
	return name

func _start(playthrough: int, carried: Dictionary) -> bool:
	_next = {"playthrough": playthrough, "carried": carried}
	if GameSession.start_new_game():
		return true
	_next = {}
	return false

# The new game's first step: the playthrough it is.
func _begin() -> void:
	_playthrough = int(_next.get("playthrough", 1))

# The new game's step once its services are reset: what carries over into it.
func _carry_over() -> void:
	var carried: Dictionary = _next.get("carried", {})
	_next = {}
	for rule: InheritanceRule in GameDefinition.current().inheritance:
		if rule != null and carried.has(String(rule.key)):
			rule.apply(carried[String(rule.key)])
	playthrough_started.emit(_playthrough)

func _to_save_data() -> Dictionary:
	return {"playthrough": _playthrough}

func _load_save_data(section: Dictionary, _snapshot: Dictionary) -> void:
	_playthrough = maxi(SaveValues.whole_number_or(section.get("playthrough", 1), 1), 1)
