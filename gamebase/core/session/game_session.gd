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

signal new_game_started
signal continue_started(success: bool)
signal player_collapsed(money_lost: int)
signal late_night_collapse

var _handling_defeat := false
var _handling_late_night := false
var _new_game_steps: Array[Dictionary] = []

func _ready() -> void:
	register_new_game_step(&"random", NEW_GAME_ORDER_RANDOM, GameRandom.reset_new_game)
	register_new_game_step(&"world", NEW_GAME_ORDER_WORLD, WorldState.clear)
	register_new_game_step(&"player", NEW_GAME_ORDER_PLAYER, PlayerState.reset_new_game)
	register_new_game_step(&"clock", NEW_GAME_ORDER_CLOCK, _reset_clock)
	register_new_game_step(&"finish", NEW_GAME_ORDER_FINISH, WorldState.set_value.bind(NEW_GAME_FLAG, true))
	PlayerState.health_changed.connect(_on_health_changed)
	WorldClock.minute_changed.connect(_on_minute_changed)

## Registers a step that resets or seeds a service when a new game starts. Steps
## run by ascending `order`; registering the same id again replaces the step.
func register_new_game_step(id: StringName, order: int, step: Callable) -> void:
	for index: int in range(_new_game_steps.size() - 1, -1, -1):
		if _new_game_steps[index]["id"] == id:
			_new_game_steps.remove_at(index)
	_new_game_steps.append({"id": id, "order": order, "step": step})
	_new_game_steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))

func initialize_new_game_state() -> void:
	for step: Dictionary in _new_game_steps:
		(step["step"] as Callable).call()

func _reset_clock() -> void:
	var definition := GameDefinition.current()
	WorldClock.set_time(definition.start_day, definition.start_minute_of_day)


func start_new_game() -> bool:
	var definition := GameDefinition.current()
	# Validate the starting world before destroying the selected slot. A broken
	# Location/scene/transition must leave the player's existing save untouched.
	if not WorldTravel.can_travel_to(definition.start_location_id):
		GameEvents.toast("Could not open the starting location")
		return false
	if SaveManager.has_save() and not SaveManager.delete_save():
		GameEvents.toast("Could not replace the selected save slot")
		return false
	initialize_new_game_state()
	if not WorldTravel.travel_to(definition.start_location_id):
		GameEvents.toast("Could not start the new game location")
		return false
	new_game_started.emit()
	return true

func continue_game() -> bool:
	if not SaveManager.has_save():
		continue_started.emit(false)
		return false
	var success: bool = await SaveManager.load_game()
	continue_started.emit(success)
	return success

func _on_minute_changed(day: int, minute_of_day: int) -> void:
	if minute_of_day != 2 * 60 or _handling_late_night or _handling_defeat:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	_handle_late_night.call_deferred(day)

func _handle_late_night(day: int) -> void:
	var definition := GameDefinition.current()
	if _handling_late_night or _handling_defeat:
		return
	if WorldClock.day != day or WorldClock.minute_of_day != 2 * 60:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	_handling_late_night = true
	WorldClock.set_time(day, 6 * 60)
	PlayerState.set_energy(maxi(PlayerState.max_energy / 2, 1))
	PlayerState.restore_full_health()
	var current_location := WorldLocationData.find_current(get_tree())
	var returned_home := current_location != null and current_location.id == definition.home_location_id
	if not returned_home:
		if WorldTravel.travel_to(definition.home_location_id, definition.home_spawn_id):
			await WorldTravel.travel_finished
			await get_tree().process_frame
			var arrived_location := WorldLocationData.find_current(get_tree())
			returned_home = arrived_location != null and arrived_location.id == definition.home_location_id
		else:
			GameEvents.toast("Could not return home after staying up late")
	SaveManager.save_game()
	_handling_late_night = false
	late_night_collapse.emit()
	GameEvents.toast("You stayed up too late and woke at home with reduced energy" if returned_home else "You stayed up too late and recovered with reduced energy")

func _on_health_changed(current: int, _maximum: int) -> void:
	if current > 0 or _handling_defeat:
		return
	_handle_player_defeat.call_deferred()

func _handle_player_defeat() -> void:
	var definition := GameDefinition.current()
	if _handling_defeat or PlayerState.health > 0:
		return
	_handling_defeat = true
	var loss := 0
	if PlayerState.money > 0:
		loss = PlayerState.lose_money(maxi(int(ceil(float(PlayerState.money) * 0.10)), 1))
	WorldClock.set_time(WorldClock.day + 1, 6 * 60)
	PlayerState.restore_full_energy()
	PlayerState.restore_full_health()
	var current_location := WorldLocationData.find_current(get_tree())
	var returned_home := current_location != null and current_location.id == definition.home_location_id
	if not returned_home:
		if WorldTravel.travel_to(definition.home_location_id, definition.home_spawn_id):
			await WorldTravel.travel_finished
			await get_tree().process_frame
			var arrived_location := WorldLocationData.find_current(get_tree())
			returned_home = arrived_location != null and arrived_location.id == definition.home_location_id
		else:
			GameEvents.toast("Could not return home after collapse")
	SaveManager.save_game()
	_handling_defeat = false
	player_collapsed.emit(loss)
	if returned_home:
		GameEvents.toastf("You collapsed and lost %dg", [loss]) if loss > 0 else GameEvents.toast("You collapsed and woke up at home")
	else:
		GameEvents.toastf("You collapsed, lost %dg, and recovered where you fell", [loss]) if loss > 0 else GameEvents.toast("You collapsed and recovered where you fell")
