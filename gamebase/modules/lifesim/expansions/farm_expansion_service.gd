class_name FarmExpansionService
extends Node

## The farm expansions (`FarmExpansionData`, such as a big coop or barn) the
## player has bought, and whether the next one can be bought. A bought expansion
## raises how many animals its housing holds, which `AnimalState` reads through
## `get_capacity()`.
##
## An expansion is offered once its condition holds and the expansions it
## requires are bought. Buying it takes its money and materials together, or
## nothing, and it stays bought. What is bought lives in `WorldState`
## (`farm_expansions:completed`), so it is saved with the world and a new game
## has none. `expansion_completed` announces each purchase.

signal expansion_completed(farm_expansion_id: StringName, housing_id: StringName, capacity: int)

const STATE_KEY := &"farm_expansions:completed"

var _purchasing: Dictionary = {}

func get_expansion(expansion_id: StringName) -> FarmExpansionData:
	return FarmExpansionData.find(expansion_id)

func is_completed(expansion_id: StringName) -> bool:
	return bool(_get_state().get(String(expansion_id), false))

func is_available(expansion_id: StringName) -> bool:
	var data := get_expansion(expansion_id)
	if data == null or is_completed(expansion_id):
		return false
	if not GameRules.check(data.condition):
		return false
	for prerequisite: StringName in data.prerequisites:
		if not is_completed(prerequisite):
			return false
	return true

func can_purchase(expansion_id: StringName) -> bool:
	var data := get_expansion(expansion_id)
	if data == null or not is_available(expansion_id):
		return false
	if PlayerState.money < data.money_cost:
		return false
	return InventoryState.can_apply_transaction(data.materials, {})

func purchase(expansion_id: StringName) -> bool:
	var purchase_key := String(expansion_id)
	if _purchasing.has(purchase_key):
		return false
	var data := get_expansion(expansion_id)
	if data == null or not is_available(expansion_id):
		return false
	if not can_purchase(expansion_id):
		GameEvents.toastf("Missing money or materials for %s", [data.display_name])
		return false
	_purchasing[purchase_key] = true
	if not PlayerState.spend_money(data.money_cost):
		_purchasing.erase(purchase_key)
		GameEvents.toastf("Money changed before %s could be purchased", [data.display_name])
		return false
	if not InventoryState.apply_transaction_atomic(data.materials, {}):
		PlayerState.add_money(data.money_cost)
		_purchasing.erase(purchase_key)
		GameEvents.toastf("Materials changed before %s could be purchased", [data.display_name])
		return false
	var state := _get_state()
	state[String(expansion_id)] = true
	WorldState.set_value(STATE_KEY, state)
	expansion_completed.emit(expansion_id, data.housing_id, data.capacity_after)
	_purchasing.erase(purchase_key)
	GameEvents.toastf("Expansion complete: %s", [data.display_name])
	return true

func get_capacity(housing_id: StringName, base_capacity: int) -> int:
	var result := maxi(base_capacity, 1)
	for data: FarmExpansionData in FarmExpansionData.find_all():
		if data == null or data.housing_id != housing_id or not is_completed(data.id):
			continue
		result = maxi(result, data.capacity_after)
	return result

func get_next_expansion_for_housing(housing_id: StringName) -> FarmExpansionData:
	var candidates: Array[FarmExpansionData] = []
	for data: FarmExpansionData in FarmExpansionData.find_all():
		if data != null and data.housing_id == housing_id and not is_completed(data.id):
			candidates.append(data)
	candidates.sort_custom(func(a: FarmExpansionData, b: FarmExpansionData) -> bool: return a.capacity_after < b.capacity_after)
	for data: FarmExpansionData in candidates:
		if is_available(data.id):
			return data
	return null

func _get_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(STATE_KEY, {})
	if not raw is Dictionary:
		return {}
	var normalized: Dictionary = {}
	for raw_key: Variant in (raw as Dictionary).keys():
		var value: Variant = (raw as Dictionary)[raw_key]
		if value is bool and bool(value):
			normalized[String(raw_key)] = true
	return normalized
