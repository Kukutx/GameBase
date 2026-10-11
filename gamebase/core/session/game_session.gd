class_name GameSessionService
extends Node

const START_LOCATION_ID := &"starter_town"
const NEW_GAME_FLAG := &"system:new_game_initialized"

signal new_game_started
signal continue_started(success: bool)
signal player_collapsed(money_lost: int)
signal late_night_collapse

var _handling_defeat := false
var _handling_late_night := false

func _ready() -> void:
	PlayerState.health_changed.connect(_on_health_changed)
	WorldClock.minute_changed.connect(_on_minute_changed)

func initialize_new_game_state() -> void:
	InventoryState.clear()
	WorldState.clear()
	AnimalState.reset_new_game()
	PlayerState.reset_new_game()
	RelationshipState.clear()
	NpcMemory.clear()
	QuestState.load_save_data({})
	Skills.reset_new_game()
	BuffState.clear()
	ShippingState.reset_new_game()
	FishingState.reset_new_game()
	WorldClock.set_time(1, 8 * 60)
	# Reset through the weather save API so current_weather is recalculated for
	# Day 1 even when the previous session was already on Day 1 with another seed.
	WeatherState.load_save_data({"world_seed": 93017})
	InventoryState.add_item_by_id(&"hoe", 1)
	InventoryState.add_item_by_id(&"watering_can", 1)
	InventoryState.add_item_by_id(&"pickaxe", 1)
	InventoryState.add_item_by_id(&"rusty_sword", 1)
	InventoryState.add_item_by_id(&"fishing_rod", 1)
	InventoryState.add_item_by_id(&"turnip_seeds", 10)
	InventoryState.add_item_by_id(&"hay", 20)
	QuestState.reset_new_game()
	WorldState.set_value(NEW_GAME_FLAG, true)

func start_new_game() -> bool:
	# Validate the starting world before destroying the selected slot. A broken
	# Location/scene/transition must leave the player's existing save untouched.
	if not WorldTravel.can_travel_to(START_LOCATION_ID):
		GameEvents.toast("Could not open the starting location")
		return false
	if SaveManager.has_save() and not SaveManager.delete_save():
		GameEvents.toast("Could not replace the selected save slot")
		return false
	initialize_new_game_state()
	if not WorldTravel.travel_to(START_LOCATION_ID):
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
	var current_location := ContentDB.get_current_location(get_tree())
	var returned_home := current_location != null and current_location.id == &"player_home"
	if not returned_home:
		if WorldTravel.travel_to(&"player_home", &"from_town"):
			await WorldTravel.travel_finished
			await get_tree().process_frame
			var arrived_location := ContentDB.get_current_location(get_tree())
			returned_home = arrived_location != null and arrived_location.id == &"player_home"
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
	if _handling_defeat or PlayerState.health > 0:
		return
	_handling_defeat = true
	var loss := 0
	if PlayerState.money > 0:
		loss = PlayerState.lose_money(maxi(int(ceil(float(PlayerState.money) * 0.10)), 1))
	WorldClock.set_time(WorldClock.day + 1, 6 * 60)
	PlayerState.restore_full_energy()
	PlayerState.restore_full_health()
	var current_location := ContentDB.get_current_location(get_tree())
	var returned_home := current_location != null and current_location.id == &"player_home"
	if not returned_home:
		if WorldTravel.travel_to(&"player_home", &"from_town"):
			await WorldTravel.travel_finished
			await get_tree().process_frame
			var arrived_location := ContentDB.get_current_location(get_tree())
			returned_home = arrived_location != null and arrived_location.id == &"player_home"
		else:
			GameEvents.toast("Could not return home after collapse")
	SaveManager.save_game()
	_handling_defeat = false
	player_collapsed.emit(loss)
	if returned_home:
		GameEvents.toastf("You collapsed and lost %dg", [loss]) if loss > 0 else GameEvents.toast("You collapsed and woke up at home")
	else:
		GameEvents.toastf("You collapsed, lost %dg, and recovered where you fell", [loss]) if loss > 0 else GameEvents.toast("You collapsed and recovered where you fell")
