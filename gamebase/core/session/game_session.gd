class_name GameSessionService
extends Node

## The game from the title screen to play and back: it starts a new game (each
## service's new-game step in order, then the start location), continues the
## selected slot's save through `SaveManager`, and returns to the title. It also
## counts the time played, and takes the player out of play to wake at home
## when a module knocks them out (`pass_out()`: combat's defeat, lifesim's late
## night). While the session changes (`is_changing()`: a new game is set up or
## a save loads), what the services announce is not play; `play_started` marks
## the end of it.

const NEW_GAME_FLAG := &"system:new_game_initialized"
## The session's section of a save: the time played.
const SAVE_SECTION := &"session"
## Orders of the new-game steps the session runs itself. A game registers its own
## steps between them with `register_new_game_step()`.
const NEW_GAME_ORDER_SESSION := 50
const NEW_GAME_ORDER_RANDOM := 100
const NEW_GAME_ORDER_WORLD := 200
const NEW_GAME_ORDER_VITALS := 400
const NEW_GAME_ORDER_CLOCK := 1200
const NEW_GAME_ORDER_FINISH := 10000

## Emitted when a new game is ready to play: its start location is open with
## the player placed.
signal new_game_started
## Emitted when a new game that started cannot open its start location. Its
## steps already reset the services and its slot was replaced, so the player
## stays where they started it (the title screen).
signal new_game_failed
## Emitted when play starts after the session changed: a new game is ready, or
## a save finished loading. Mail checks its deliveries again here. What is
## announced while the session changes (`is_changing()`) is not replayed:
## `GameTriggers` and the quests drop it, since a load or a new game's steps
## set the state those events stand for.
signal play_started
## Emitted when the player starts to pass out (`pass_out()`), before anything
## changes: a run in progress ends with it.
signal passing_out(cause: StringName)
## Emitted when the player has passed out, woken and been saved: at home, or
## where they fell when home could not open.
signal passed_out(cause: StringName, woke_at_home: bool)

## The cause a defeat passes out with: the player lost what keeps them in the
## fight (combat's health).
const CAUSE_DEFEAT := &"defeat"

var _passing_out := false
var _new_game_steps: Array[Dictionary] = []
var _starting_new_game := false
var _activity_ends: Array[Callable] = []
# Seconds played in the running game, and whether play runs: from
# `play_started` until the title.
var _play_seconds := 0.0
var _playing := false

func _ready() -> void:
	SaveManager.register_section(SaveSection.new(SAVE_SECTION, GameSaveManager.SECTION_ORDER_SESSION, _to_save_data, _load_save_data))
	register_new_game_step(SAVE_SECTION, NEW_GAME_ORDER_SESSION, _reset_play_time)
	register_new_game_step(&"random", NEW_GAME_ORDER_RANDOM, GameRandom.reset_new_game)
	register_new_game_step(&"world", NEW_GAME_ORDER_WORLD, WorldState.clear)
	register_new_game_step(&"vitals", NEW_GAME_ORDER_VITALS, Vitals.reset_new_game)
	register_new_game_step(&"clock", NEW_GAME_ORDER_CLOCK, _reset_clock)
	register_new_game_step(&"finish", NEW_GAME_ORDER_FINISH, WorldState.set_value.bind(NEW_GAME_FLAG, true))
	SaveManager.load_completed.connect(_on_load_completed)

func _process(delta: float) -> void:
	# The session pauses with the world, so a paused game adds no time.
	if _playing and not is_changing():
		_play_seconds += delta

## Whole seconds played in the running game: counted while play runs (from
## `play_started` until the title), not while the world is paused or the
## session changes. A save keeps them, and a new game starts at 0.
func get_play_seconds() -> int:
	return floori(_play_seconds)

## The seconds played that `snapshot`, a save, holds.
static func read_play_seconds(snapshot: Dictionary) -> int:
	var section: Variant = snapshot.get(String(SAVE_SECTION), {})
	return SaveValues.count((section as Dictionary).get("play_seconds", 0)) if section is Dictionary else 0

func _to_save_data() -> Dictionary:
	return {"play_seconds": get_play_seconds()}

func _load_save_data(_section: Dictionary, snapshot: Dictionary) -> void:
	_play_seconds = float(read_play_seconds(snapshot))

func _reset_play_time() -> void:
	_play_seconds = 0.0

## Registers a step that resets or seeds a service when a new game starts. Steps
## run by ascending `order`; registering the same id again replaces the step.
func register_new_game_step(id: StringName, order: int, step: Callable) -> void:
	for index: int in range(_new_game_steps.size() - 1, -1, -1):
		if _new_game_steps[index]["id"] == id:
			_new_game_steps.remove_at(index)
	_new_game_steps.append({"id": id, "order": order, "step": step})
	_new_game_steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))

## Registers `end`, which ends an activity the player may be in (fishing, a
## minigame) without its outcome. `end_activities()` calls it before something
## takes the player out of play: passing out, a load, a new game, the title.
func register_activity_end(end: Callable) -> void:
	if not _activity_ends.has(end):
		_activity_ends.append(end)

## Ends every activity the player is in (see `register_activity_end`).
func end_activities() -> void:
	for end: Callable in _activity_ends:
		if end.is_valid():
			end.call()

## Leaves the session for the title screen (the game's main scene): ends the
## player's activities and gives back every lock first. False while a travel,
## a load or a new game changes the scene: that change would replace the title.
func return_to_title() -> bool:
	if is_changing() or WorldTravel.is_traveling():
		return false
	end_activities()
	_playing = false
	# Nothing of the session holds the controls or the screen on the title
	# screen, and no travel leads there.
	InputLock.clear()
	Transition.reset()
	WorldTravel.reset()
	get_tree().change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	return true

func initialize_new_game_state() -> void:
	var starting := _starting_new_game
	_starting_new_game = true
	for step: Dictionary in _new_game_steps:
		(step["step"] as Callable).call()
	_starting_new_game = starting

## Whether a new game is being set up: from the new-game steps resetting the
## services until the start location is open with the player placed. What the
## services and the location announce meanwhile is the setup, not play
## (`GameTriggers` ignores it).
func is_starting_new_game() -> bool:
	return _starting_new_game

## Whether the session is changing: a new game is being set up or a save is
## being restored. What the services and the location announce meanwhile is
## the change, not play; `play_started` follows it.
func is_changing() -> bool:
	return _starting_new_game or GameSaveManager.is_restoring()

func _reset_clock() -> void:
	var definition := GameDefinition.current()
	WorldClock.set_time(definition.start_day, definition.start_minute_of_day)

## Starts a new game in the selected slot: ends what the player was doing
## (`end_activities()`, for a new game started during play), resets the
## services and opens the start location; `new_game_started` follows once the
## player stands in it. False when the start location cannot open, which is
## checked before the slot's save or the session changes.
func start_new_game() -> bool:
	var definition := GameDefinition.current()
	# Validate the starting world before destroying the selected slot. A broken
	# Location/scene/transition must leave the player's existing save untouched.
	if not WorldTravel.can_travel_to(definition.start_location_id):
		GameEvents.toast("Could not open the starting location")
		return false
	# The slot may hold a save this build cannot read; the title screen asked
	# before replacing it.
	if SaveManager.has_files() and not SaveManager.delete_save():
		GameEvents.toast("Could not replace the selected save slot")
		return false
	end_activities()
	_starting_new_game = true
	initialize_new_game_state()
	WorldTravel.travel_ended.connect(_on_start_travel_ended, CONNECT_ONE_SHOT)
	if not WorldTravel.travel_to(definition.start_location_id):
		# Still connected: the travel never started, so nothing announced it.
		if WorldTravel.travel_ended.is_connected(_on_start_travel_ended):
			WorldTravel.travel_ended.disconnect(_on_start_travel_ended)
			_starting_new_game = false
			GameEvents.toast("Could not start the new game location")
		return false
	return true

func _on_load_completed(success: bool, _message: String) -> void:
	if success:
		_start_play()

func _start_play() -> void:
	_playing = true
	play_started.emit()

func _on_start_travel_ended(arrived: bool) -> void:
	_starting_new_game = false
	if arrived:
		new_game_started.emit()
		_start_play()
	else:
		GameEvents.toast("Could not start the new game location")
		new_game_failed.emit()

## Loads the selected slot's save; `SaveManager.load_completed` says how it
## went, also when the slot holds none.
func continue_game() -> bool:
	return await SaveManager.load_game()

## Takes the player out of play to wake at home: `passing_out` first, then it
## ends their activities, calls `recover` (what the cause restores or takes,
## such as the vitals and money, before the new day's payouts arrive), moves
## the clock to the next morning (`GameCalendar.wake_minute`, counted from
## `from_day` and `from_minute`, now when -1), takes them home and saves;
## `passed_out` follows. Returns
## whether they woke at home, and false at once while they already pass out.
## The module that knocks them out names the `cause` and tells the player.
func pass_out(cause: StringName, recover := Callable(), from_day := -1, from_minute := -1) -> bool:
	if _passing_out:
		return false
	_passing_out = true
	passing_out.emit(cause)
	end_activities()
	var calendar := GameCalendar.current()
	var day := WorldClock.day if from_day < 0 else from_day
	var minute := WorldClock.minute_of_day if from_minute < 0 else from_minute
	if recover.is_valid():
		recover.call()
	WorldClock.set_time(calendar.get_wake_day(day, minute), calendar.wake_minute)
	var woke_at_home := await _return_home()
	SaveManager.save_game()
	_passing_out = false
	passed_out.emit(cause, woke_at_home)
	return woke_at_home

## Whether the player is passing out (`pass_out()`).
func is_passing_out() -> bool:
	return _passing_out

# Takes the player to the game's home spawn unless they are home already.
# True when they stand at home after it.
func _return_home() -> bool:
	# A travel under way (a portal the player stepped through as it happened)
	# arrives first; the player is then where it took them.
	if WorldTravel.is_traveling():
		await WorldTravel.wait_until_arrived()
	if _is_home():
		return true
	var definition := GameDefinition.current()
	if not await WorldTravel.go_to(definition.home_location_id, definition.home_spawn_id):
		return false
	return _is_home()

func _is_home() -> bool:
	var location := WorldLocationData.find_current(get_tree())
	return location != null and location.id == GameDefinition.current().home_location_id
