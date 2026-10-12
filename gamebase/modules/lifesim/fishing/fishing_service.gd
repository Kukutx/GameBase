class_name FishingService
extends Node

enum CastState {
	IDLE,
	WAITING,
	BITE,
}

signal fish_caught(fish_id: StringName, item_id: StringName)
signal cast_state_changed(state: CastState, message: String)
signal fishing_active_changed(active: bool)

@export var bite_delay_range := Vector2(0.8, 2.2)
@export_range(0.2, 5.0, 0.1) var bite_window := 1.2

var cast_count := 0
var cast_state: CastState = CastState.IDLE
## Minigame (`MiniGameHost`) the player plays to land a biting fish; empty lands
## it as soon as the player reels in.
var reel_minigame_id: StringName = &""

var _time_remaining := 0.0
var _pending_fish: FishData
var _active_location_id: StringName
var _action_busy := false

func _process(delta: float) -> void:
	if cast_state == CastState.IDLE:
		return
	_time_remaining -= delta
	if _time_remaining > 0.0:
		return
	if cast_state == CastState.WAITING:
		cast_state = CastState.BITE
		_time_remaining = get_effective_bite_window()
		var prompt := InputPrompts.get_action_prompt(&"interact")
		cast_state_changed.emit(cast_state, tr("BITE! Press %s to reel in") % prompt)
		GameEvents.toast(tr("BITE! Press %s") % prompt)
		return
	if cast_state == CastState.BITE:
		_finish_session(false, tr("The fish got away"))

func _unhandled_input(event: InputEvent) -> void:
	if cast_state != CastState.BITE or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if reel_minigame_id == &"":
		reel_in()
	else:
		reel_in_with_minigame()

## Plays the reel minigame for the biting fish and lands it on a win. The world,
## and with it the bite timer, is paused while the minigame runs.
func reel_in_with_minigame() -> bool:
	if cast_state != CastState.BITE or _pending_fish == null or MiniGameHost.is_running():
		return false
	var fish := _pending_fish
	var result: MiniGameResult = await MiniGameHost.run(reel_minigame_id, {
		"difficulty": fish.difficulty,
		"zone_scale": get_effective_bite_window() / maxf(bite_window, 0.01),
		"seed": "%d:%d" % [WorldClock.day, cast_count],
	})
	# A load or a new game during the minigame replaces the session.
	if cast_state != CastState.BITE or _pending_fish != fish:
		return false
	if result.success:
		return reel_in()
	_finish_session(false, tr("Fishing cancelled") if result.cancelled else tr("The fish got away"))
	return false

func get_available_fish(location_id: StringName, day: int = -1, minute_of_day: int = -1) -> Array[FishData]:
	var resolved_day := WorldClock.day if day < 1 else day
	var resolved_minute := WorldClock.minute_of_day if minute_of_day < 0 else minute_of_day
	var weather_name := WeatherState.get_weather_name(WeatherState.get_weather_for_day(resolved_day))
	var result: Array[FishData] = []
	for fish: FishData in FishData.find_all():
		if fish != null and fish.is_available(location_id, resolved_day, resolved_minute, weather_name):
			result.append(fish)
	return result

func roll_catch(location_id: StringName) -> FishData:
	var available := get_available_fish(location_id)
	if available.is_empty():
		return null
	var total_weight := 0.0
	for fish: FishData in available:
		total_weight += maxf(fish.catch_weight, 0.0)
	if total_weight <= 0.0:
		return null
	var rng := GameRandom.stream("fish:%d:%d:%s" % [WorldClock.day, cast_count, location_id])
	cast_count += 1
	var roll := rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for fish: FishData in available:
		cursor += maxf(fish.catch_weight, 0.0)
		if roll <= cursor:
			return fish
	return available.back()

func start_cast(location_id: StringName, energy_cost: int = 4) -> bool:
	if _action_busy:
		return false
	_action_busy = true
	var result := _start_cast_internal(location_id, energy_cost)
	_action_busy = false
	return result

func _start_cast_internal(location_id: StringName, energy_cost: int) -> bool:
	if cast_state != CastState.IDLE:
		GameEvents.toast("You are already fishing")
		return false
	if get_available_fish(location_id).is_empty():
		GameEvents.toast("Nothing is biting right now")
		return false
	if not PlayerState.consume_energy(energy_cost):
		GameEvents.toast("Not enough energy to fish")
		return false
	var fish := roll_catch(location_id)
	if fish == null:
		PlayerState.restore_energy(energy_cost)
		return false
	_pending_fish = fish
	_active_location_id = location_id
	var rng := GameRandom.stream("bite:%d:%d:%s" % [WorldClock.day, cast_count, location_id])
	var min_delay := minf(bite_delay_range.x, bite_delay_range.y)
	var max_delay := maxf(bite_delay_range.x, bite_delay_range.y)
	_time_remaining = rng.randf_range(maxf(min_delay, 0.05), maxf(max_delay, 0.05)) * get_effective_wait_multiplier()
	cast_state = CastState.WAITING
	InputLock.lock(&"fishing_cast")
	fishing_active_changed.emit(true)
	cast_state_changed.emit(cast_state, tr("Waiting for a bite..."))
	GameEvents.toast("Cast the line... wait for a bite")
	return true

func reel_in() -> bool:
	if _action_busy:
		return false
	_action_busy = true
	var result := _reel_in_internal()
	_action_busy = false
	return result

func _reel_in_internal() -> bool:
	if cast_state != CastState.BITE or _pending_fish == null:
		return false
	var fish := _pending_fish
	var caught := _award_fish(fish)
	var item := ItemData.find(fish.item_id)
	var caught_name := tr(item.display_name) if item != null else String(fish.id).capitalize()
	_finish_session(caught, tr("Caught %s") % caught_name if caught else tr("The fish got away"))
	return caught

func cancel_cast(announce: bool = true) -> void:
	if cast_state == CastState.IDLE:
		return
	_finish_session(false, tr("Fishing cancelled") if announce else "")

# Immediate deterministic path for tests/headless acceptance.
func try_fish(location_id: StringName, energy_cost: int = 4) -> bool:
	if _action_busy:
		return false
	_action_busy = true
	var result := _try_fish_internal(location_id, energy_cost)
	_action_busy = false
	return result

func _try_fish_internal(location_id: StringName, energy_cost: int) -> bool:
	if get_available_fish(location_id).is_empty():
		GameEvents.toast("Nothing is biting right now")
		return false
	if not PlayerState.consume_energy(energy_cost):
		GameEvents.toast("Not enough energy to fish")
		return false
	var fish := roll_catch(location_id)
	if fish == null:
		PlayerState.restore_energy(energy_cost)
		return false
	var caught := _award_fish(fish)
	if not caught:
		PlayerState.restore_energy(energy_cost)
	return caught

func is_active() -> bool:
	return cast_state != CastState.IDLE

func get_effective_wait_multiplier() -> float:
	return GameStats.get_multiplier(&"fishing_wait")

func get_effective_bite_window() -> float:
	return GameStats.apply(&"fishing_window", bite_window)

func get_status_text() -> String:
	match cast_state:
		CastState.WAITING:
			return tr("Fishing · Waiting...")
		CastState.BITE:
			return tr("Fishing · BITE!  Press %s") % InputPrompts.get_action_prompt(&"interact")
		_:
			return ""

func reset_new_game() -> void:
	cast_count = 0
	_reset_session()

func to_save_data() -> Dictionary:
	return {"cast_count": cast_count}

func load_save_data(data: Dictionary) -> void:
	var raw_cast_count: Variant = data.get("cast_count", 0)
	cast_count = SaveValues.count(raw_cast_count)
	_reset_session()

func _award_fish(fish: FishData) -> bool:
	if fish == null:
		return false
	var item := ItemData.find(fish.item_id)
	if item == null:
		return false
	var remaining := InventoryState.add_item(item, 1)
	if remaining > 0:
		GameEvents.toast("Inventory is full")
		return false
	fish_caught.emit(fish.id, fish.item_id)
	LifesimEvents.fish_caught.emit(fish.id, fish.item_id)
	GameEvents.toastf("Caught %s", [item.display_name])
	return true

func _finish_session(success: bool, message: String) -> void:
	_reset_session()
	fishing_active_changed.emit(false)
	cast_state_changed.emit(CastState.IDLE, message)
	if not success and not message.is_empty():
		GameEvents.toast(message)

func _reset_session() -> void:
	InputLock.unlock(&"fishing_cast")
	cast_state = CastState.IDLE
	_time_remaining = 0.0
	_pending_fish = null
	_active_location_id = &""
