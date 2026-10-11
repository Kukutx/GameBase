class_name DailyContractService
extends Node

signal contract_changed(contract: Dictionary)
signal contract_completed(contract: Dictionary)
signal contract_claimed(contract: Dictionary)

const STATE_KEY := &"daily_contract:state"
const FORAGE := &"forage"
const FISH := &"fish"
const MINE := &"mine"
const SHIP := &"ship"
const HARVEST := &"harvest"

func _ready() -> void:
	WorldClock.day_changed.connect(_on_day_changed)
	GameEvents.item_foraged.connect(_on_item_foraged)
	GameEvents.fish_caught.connect(_on_fish_caught)
	GameEvents.resource_mined.connect(_on_resource_mined)
	GameEvents.crop_harvested.connect(_on_crop_harvested)
	ShippingState.item_shipped.connect(_on_item_shipped)
	_ensure_contract()

func get_contract() -> Dictionary:
	_ensure_contract()
	return _get_state().duplicate(true)

func generate_contract_for_day(day: int) -> Dictionary:
	var candidates := _build_candidates(maxi(day, 1))
	if candidates.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("daily_contract:%d:%d" % [WeatherState.world_seed, maxi(day, 1)])) + 1
	var base: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	base["generated_day"] = maxi(day, 1)
	var duration_days := maxi(int(base.get("duration_days", 2)), 1)
	base.erase("duration_days")
	base["expires_day"] = maxi(day, 1) + duration_days
	base["accepted"] = false
	base["progress"] = 0
	base["completed"] = false
	base["claimed"] = false
	return base

func accept() -> bool:
	var state := get_contract()
	if state.is_empty() or bool(state.get("accepted", false)) or bool(state.get("claimed", false)):
		return false
	state["accepted"] = true
	_set_state(state)
	GameEvents.toastf("Accepted: %s", [get_display_title(state)])
	return true

func claim() -> int:
	var state := get_contract()
	if state.is_empty() or not bool(state.get("accepted", false)) or not bool(state.get("completed", false)) or bool(state.get("claimed", false)):
		return 0
	var reward := maxi(int(state.get("reward_money", 0)), 0)
	# Commit the one-time claim before emitting money_changed. Money listeners can
	# synchronously call claim() again; they must observe claimed=true and receive
	# no second payout.
	state["claimed"] = true
	_set_state(state)
	if reward > 0:
		PlayerState.add_money(reward)
	contract_claimed.emit(state.duplicate(true))
	GameEvents.toastf("Contract complete · +%dg", [reward])
	return reward

func get_summary() -> String:
	var state := get_contract()
	if state.is_empty():
		return tr("No notice available")
	if bool(state.get("claimed", false)):
		return tr("Daily contract claimed")
	var title := get_display_title(state)
	if not bool(state.get("accepted", false)):
		return tr("Offer: %s") % title
	var expires_day := int(state.get("expires_day", WorldClock.day))
	if bool(state.get("completed", false)):
		return tr("%s · Complete — claim at board · due Day %d") % [title, expires_day]
	return tr("%s · %d/%d · due Day %d") % [title, int(state.get("progress", 0)), int(state.get("required", 1)), expires_day]

# The title is built from the stored objective when it is shown, so it follows
# the current language and the current name of the item.
func get_display_title(state: Dictionary) -> String:
	var item := ContentDB.get_item(StringName(String(state.get("target_item_id", ""))))
	if item == null:
		return tr("Daily contract")
	var amount := maxi(int(state.get("required", 1)), 1)
	var item_name := tr(item.display_name)
	match StringName(String(state.get("objective_type", ""))):
		FORAGE: return tr("Forage %d %s") % [amount, item_name]
		FISH: return tr("Catch %d %s") % [amount, item_name]
		MINE: return tr("Mine %d %s") % [amount, item_name]
		SHIP: return tr("Ship %d %s") % [amount, item_name]
		HARVEST: return tr("Harvest %d %s") % [amount, item_name]
		_: return tr("Collect %d %s") % [amount, item_name]

func get_display_description(state: Dictionary) -> String:
	return tr("%s for the town request.") % get_display_title(state)

func _ensure_contract() -> void:
	var state := _get_state()
	if state.is_empty():
		_set_state(generate_contract_for_day(WorldClock.day))
		return
	var generated_day := maxi(int(state.get("generated_day", 0)), 0)
	var expires_day := maxi(int(state.get("expires_day", generated_day)), generated_day)
	var accepted := bool(state.get("accepted", false))
	var completed := bool(state.get("completed", false))
	var claimed := bool(state.get("claimed", false))
	if not completed and not claimed and not _is_contract_content_valid(state):
		_set_state(generate_contract_for_day(WorldClock.day))
		return
	if claimed and WorldClock.day > generated_day:
		_set_state(generate_contract_for_day(WorldClock.day))
	elif not accepted and WorldClock.day > generated_day:
		_set_state(generate_contract_for_day(WorldClock.day))
	elif accepted and not completed and WorldClock.day > expires_day:
		GameEvents.toast("Daily contract expired")
		_set_state(generate_contract_for_day(WorldClock.day))

func _is_contract_content_valid(state: Dictionary) -> bool:
	var objective := StringName(String(state.get("objective_type", "")))
	var target := StringName(String(state.get("target_item_id", "")))
	if objective == &"" or target == &"" or ContentDB.get_item(target) == null:
		return false
	match objective:
		FORAGE:
			for entry: ForageEntryData in ContentDB.get_all_forage_entries():
				if entry != null and entry.item_id == target:
					return true
			return false
		FISH:
			for fish: FishData in ContentDB.get_all_fish():
				if fish != null and fish.item_id == target:
					return true
			return false
		MINE:
			for node: MiningNodeData in ContentDB.get_all_mining_nodes():
				if node != null and node.drop_item_id == target:
					return true
			return false
		HARVEST:
			for crop: CropData in ContentDB.get_all_crops():
				if crop != null and crop.harvest_item_id == target:
					return true
			return false
		SHIP:
			# Shipping can still be completed from stock the player already owns, so
			# item existence is enough even if its original acquisition source moved.
			return true
		_:
			return false

func _build_candidates(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var season := GameClock.get_season_name_for_day(day)
	var unique_forage: Dictionary = {}
	for entry: ForageEntryData in ContentDB.get_all_forage_entries():
		if entry == null or (not entry.seasons.is_empty() and not entry.seasons.has(season)):
			continue
		# Forage/ship contracts last through generated_day + 2. Seasonal forage
		# must remain obtainable for that whole window; otherwise a late-season
		# offer can become impossible as soon as the calendar rolls over.
		if not _forage_entry_available_through_deadline(entry, day, 2):
			continue
		unique_forage[String(entry.item_id)] = true
	for raw_id: Variant in unique_forage.keys():
		_add_candidate(result, FORAGE, StringName(String(raw_id)), 3, 90, 2)
		_add_candidate(result, SHIP, StringName(String(raw_id)), 2, 110, 2)

	for fish: FishData in ContentDB.get_all_fish():
		if fish == null or (not fish.seasons.is_empty() and not fish.seasons.has(season)):
			continue
		if not _fish_has_contract_window(fish, day, 2):
			continue
		_add_candidate(result, FISH, fish.item_id, 1, 140 + fish.difficulty * 20, 1)

	var deepest_mine_floor := MineState.get_deepest_floor()
	for node: MiningNodeData in ContentDB.get_all_mining_nodes():
		if node == null or node.drop_item_id == &"":
			continue
		if deepest_mine_floor < node.minimum_mine_floor:
			continue
		_add_candidate(result, MINE, node.drop_item_id, 3, 130, 2)

	var day_of_season := posmod(maxi(day, 1) - 1, GameClock.DAYS_PER_SEASON) + 1
	var growth_days_left := GameClock.DAYS_PER_SEASON - day_of_season + 1
	for crop: CropData in ContentDB.get_all_crops():
		if crop == null or not crop.can_grow_in(season):
			continue
		if crop.days_to_mature > growth_days_left:
			continue
		_add_candidate(result, HARVEST, crop.harvest_item_id, 2, 180, 2, maxi(7, crop.days_to_mature))
	return result

func _add_candidate(result: Array[Dictionary], objective_type: StringName, item_id: StringName, required: int, base_reward: int, value_multiplier: int, duration_days: int = 2) -> void:
	var item := ContentDB.get_item(item_id)
	if item == null:
		return
	var amount := maxi(required, 1)
	var reward := base_reward + maxi(item.sell_price, 5) * amount * maxi(value_multiplier, 1)
	result.append({
		"objective_type": String(objective_type),
		"target_item_id": String(item_id),
		"required": amount,
		"reward_money": reward,
		"duration_days": maxi(duration_days, 1),
	})

func _forage_entry_available_through_deadline(entry: ForageEntryData, start_day: int, duration_days: int) -> bool:
	if entry == null:
		return false
	for offset in range(maxi(duration_days, 0) + 1):
		var candidate_day := maxi(start_day, 1) + offset
		var candidate_season := GameClock.get_season_name_for_day(candidate_day)
		if not entry.seasons.is_empty() and not entry.seasons.has(candidate_season):
			return false
	return true

func _fish_has_contract_window(fish: FishData, start_day: int, duration_days: int) -> bool:
	if fish == null:
		return false
	var location_id: StringName = fish.locations[0] if not fish.locations.is_empty() else &""
	for offset in range(maxi(duration_days, 0) + 1):
		var candidate_day: int = maxi(start_day, 1) + offset
		var weather_name: String = WeatherState.get_weather_name(WeatherState.get_weather_for_day(candidate_day))
		var minute: int = fish.start_minute
		if candidate_day == WorldClock.day:
			var now: int = WorldClock.minute_of_day
			if fish.start_minute <= fish.end_minute:
				minute = maxi(now, fish.start_minute)
			else:
				minute = now if now < fish.end_minute or now >= fish.start_minute else fish.start_minute
		if fish.is_available(location_id, candidate_day, minute, weather_name):
			return true
	return false

func _advance_progress(objective_type: StringName, item_id: StringName, quantity: int) -> void:
	if quantity <= 0:
		return
	var state := _get_state()
	if state.is_empty() or not bool(state.get("accepted", false)) or bool(state.get("completed", false)) or bool(state.get("claimed", false)):
		return
	if StringName(String(state.get("objective_type", ""))) != objective_type or StringName(String(state.get("target_item_id", ""))) != item_id:
		return
	var required := maxi(int(state.get("required", 1)), 1)
	state["progress"] = mini(int(state.get("progress", 0)) + quantity, required)
	if int(state["progress"]) >= required:
		state["completed"] = true
	_set_state(state)
	if bool(state["completed"]):
		contract_completed.emit(state.duplicate(true))
		GameEvents.toast("Daily contract complete — return to the notice board")

func _get_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(STATE_KEY, {})
	if not raw is Dictionary:
		return {}
	var source: Dictionary = raw
	var state: Dictionary = source.duplicate(true)
	state["objective_type"] = _safe_string(source.get("objective_type", ""))
	state["target_item_id"] = _safe_string(source.get("target_item_id", ""))
	var generated_day := maxi(_safe_int(source.get("generated_day", 0), 0), 0)
	state["generated_day"] = generated_day
	state["expires_day"] = maxi(_safe_int(source.get("expires_day", generated_day), generated_day), generated_day)
	var required := maxi(_safe_int(source.get("required", 1), 1), 1)
	state["required"] = required
	state["progress"] = clampi(_safe_int(source.get("progress", 0), 0), 0, required)
	state["reward_money"] = maxi(_safe_int(source.get("reward_money", 0), 0), 0)
	var claimed := source.get("claimed", false) is bool and bool(source.get("claimed", false))
	var completed := claimed or (source.get("completed", false) is bool and bool(source.get("completed", false)))
	var accepted := completed or (source.get("accepted", false) is bool and bool(source.get("accepted", false)))
	state["accepted"] = accepted
	state["completed"] = completed
	state["claimed"] = claimed
	return state

func _safe_int(value: Variant, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

func _safe_string(value: Variant, fallback := "") -> String:
	if value is String or value is StringName:
		return String(value)
	return fallback

func _set_state(state: Dictionary) -> void:
	WorldState.set_value(STATE_KEY, state.duplicate(true))
	contract_changed.emit(state.duplicate(true))

func _on_day_changed(_day: int) -> void:
	_ensure_contract()

func _on_item_foraged(item_id: StringName, quantity: int) -> void:
	_advance_progress(FORAGE, item_id, quantity)

func _on_fish_caught(_fish_id: StringName, item_id: StringName) -> void:
	_advance_progress(FISH, item_id, 1)

func _on_resource_mined(_node_id: StringName, item_id: StringName, quantity: int) -> void:
	_advance_progress(MINE, item_id, quantity)

func _on_crop_harvested(_crop_id: StringName, item_id: StringName, quantity: int) -> void:
	_advance_progress(HARVEST, item_id, quantity)

func _on_item_shipped(item_id: StringName, quantity: int, _value: int) -> void:
	_advance_progress(SHIP, item_id, quantity)
