class_name ShopData
extends ContentEntry

@export var display_name: String = "Shop"
@export var stock: Dictionary = {}
@export var seasonal_stock: Dictionary = {}
@export var animal_stock: Array[StringName] = []

func get_stock(season_name: String = "") -> Dictionary:
	var resolved_season := WorldClock.get_season_name() if season_name.is_empty() else season_name
	var result := stock.duplicate(true)
	var seasonal: Variant = seasonal_stock.get(resolved_season, {})
	if seasonal is Dictionary:
		for raw_id: Variant in seasonal.keys():
			result[String(raw_id)] = seasonal[raw_id]
	return result

func get_buy_price(item: ItemData) -> int:
	if item == null:
		return 0
	var raw_price: Variant = get_stock().get(String(item.id), item.buy_price)
	if typeof(raw_price) != TYPE_INT and typeof(raw_price) != TYPE_FLOAT:
		return 0
	return maxi(int(raw_price), 0)

func has_item(item_id: StringName) -> bool:
	return get_stock().has(String(item_id))

func has_animal(animal_id: StringName) -> bool:
	return animal_stock.has(animal_id)
