class_name GameSessionService
extends Node

const NEW_GAME_FLAG := &"system:new_game_initialized"
## Orders of the new-game steps the session runs itself. A game registers its own
## steps between them with `register_new_game_step()`.
const NEW_GAME_ORDER_RANDOM := 100
const NEW_GAME_ORDER_WORLD := 200
const NEW_GAME_ORDER_PLAYER := 400
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
## a save finished loading. A service that ignores what is announced while the
## session changes (`is_changing()`) catches up here.
signal play_started
signal continue_started(success: bool)
signal player_collapsed(money_lost: int)
signal late_night_collapse

var _handling_defeat := false
var _handling_late_night := false
var _new_game_steps: Array[Dictionary] = []
var _starting_new_game := false
var _activity_ends: Array[Callable] = []

func _ready() -> void:
	register_new_game_step(&"random", NEW_GAME_ORDER_RANDOM, GameRandom.reset_new_game)
	register_new_game_step(&"world", NEW_GAME_ORDER_WORLD, WorldState.clear)
	register_new_game_step(&"player", NEW_GAME_ORDER_PLAYER, PlayerState.reset_new_game)
	register_new_game_step(&"clock", NEW_GAME_ORDER_CLOCK, _reset_clock)
	register_new_game_step(&"finish", NEW_GAME_ORDER_FINISH, WorldState.set_value.bind(NEW_GAME_FLAG, true))
	PlayerState.health_changed.connect(_on_health_changed)
	WorldClock.minute_changed.connect(_on_minute_changed)
	SaveManager.load_completed.connect(_on_load_completed)

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
## takes the player out of play: a collapse, a defeat, a load, the title.
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
	# Nothing of the session holds the controls on the title screen.
	InputLock.clear()
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

## Starts a new game in the selected slot: resets the services and opens the
## start location; `new_game_started` follows once the player stands in it.
## False when the start location cannot open, which is checked before the
## slot's save or the session changes.
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
		play_started.emit()

func _on_start_travel_ended(arrived: bool) -> void:
	_starting_new_game = false
	if arrived:
		new_game_started.emit()
		play_started.emit()
	else:
		GameEvents.toast("Could not start the new game location")
		new_game_failed.emit()

func continue_game() -> bool:
	if not SaveManager.has_save():
		continue_started.emit(false)
		return false
	var success: bool = await SaveManager.load_game()
	continue_started.emit(success)
	return success

func _on_minute_changed(day: int, minute_of_day: int) -> void:
	if minute_of_day != GameCalendar.current().collapse_minute or _handling_late_night or _handling_defeat:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	_handle_late_night.call_deferred(day)

func _handle_late_night(day: int) -> void:
	if _handling_late_night or _handling_defeat:
		return
	var calendar := GameCalendar.current()
	# The clock may have run a few minutes on in the same frame (short game
	# minutes, a long frame, an action that passes time); the player still
	# collapses unless it was moved past the morning (they slept).
	var collapse_at := _minute_count(day, calendar.collapse_minute)
	var wake_at := _minute_count(calendar.get_wake_day(day, calendar.collapse_minute), calendar.wake_minute)
	var now := _minute_count(WorldClock.day, WorldClock.minute_of_day)
	if now < collapse_at or now >= wake_at:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	_handling_late_night = true
	end_activities()
	WorldClock.set_time(calendar.get_wake_day(day, calendar.collapse_minute), calendar.wake_minute)
	PlayerState.set_energy(maxi(PlayerState.max_energy / 2, 1))
	PlayerState.restore_full_health()
	var returned_home := await _return_home()
	if not returned_home:
		GameEvents.toast("Could not return home after staying up late")
	SaveManager.save_game()
	_handling_late_night = false
	late_night_collapse.emit()
	GameEvents.toast("You stayed up too late and woke at home with reduced energy" if returned_home else "You stayed up too late and recovered with reduced energy")

# Takes the player to the game's home spawn unless they are home already.
# True when they stand at home after it.
func _return_home() -> bool:
	# A travel under way (a portal the player stepped through as it happened)
	# arrives first; the player is then where it took them.
	if WorldTravel.is_traveling():
		await WorldTravel.wait_until_arrived()
		await get_tree().process_frame
	if _is_home():
		return true
	var definition := GameDefinition.current()
	if not await WorldTravel.go_to(definition.home_location_id, definition.home_spawn_id):
		return false
	await get_tree().process_frame
	return _is_home()

func _is_home() -> bool:
	var location := WorldLocationData.find_current(get_tree())
	return location != null and location.id == GameDefinition.current().home_location_id

# Minutes from the start of day 1 to `minute_of_day` of `day`.
static func _minute_count(day: int, minute_of_day: int) -> int:
	return (day - 1) * GameClock.MINUTES_PER_DAY + minute_of_day

func _on_health_changed(current: int, _maximum: int) -> void:
	if current > 0 or _handling_defeat:
		return
	_handle_player_defeat.call_deferred()

func _handle_player_defeat() -> void:
	var definition := GameDefinition.current()
	if _handling_defeat or PlayerState.health > 0:
		return
	_handling_defeat = true
	end_activities()
	var loss := 0
	if definition.defeat_money_loss_percent > 0 and PlayerState.money > 0:
		loss = PlayerState.lose_money(maxi(ceili(PlayerState.money * definition.defeat_money_loss_percent / 100.0), 1))
	var calendar := GameCalendar.current()
	WorldClock.set_time(calendar.get_wake_day(WorldClock.day, WorldClock.minute_of_day), calendar.wake_minute)
	PlayerState.restore_full_energy()
	PlayerState.restore_full_health()
	var returned_home := await _return_home()
	if not returned_home:
		GameEvents.toast("Could not return home after collapse")
	SaveManager.save_game()
	_handling_defeat = false
	player_collapsed.emit(loss)
	if returned_home:
		GameEvents.toastf("You collapsed and lost %dg", [loss]) if loss > 0 else GameEvents.toast("You collapsed and woke up at home")
	else:
		GameEvents.toastf("You collapsed, lost %dg, and recovered where you fell", [loss]) if loss > 0 else GameEvents.toast("You collapsed and recovered where you fell")
