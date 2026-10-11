class_name CollectionService
extends Node

signal collection_changed(category: StringName, item_id: StringName, count: int)

const STATE_KEY := &"collection:records"
const CROPS := &"crops"
const FISH := &"fish"
const MINERALS := &"minerals"
const ANIMAL_PRODUCTS := &"animal_products"
const PROCESSED := &"processed"
const FORAGE := &"forage"
const SHIPPED := &"shipped"
const CATEGORIES: Array[StringName] = [CROPS, FISH, MINERALS, ANIMAL_PRODUCTS, PROCESSED, FORAGE, SHIPPED]

func _ready() -> void:
	GameEvents.crop_harvested.connect(_on_crop_harvested)
	GameEvents.fish_caught.connect(_on_fish_caught)
	GameEvents.resource_mined.connect(_on_resource_mined)
	GameEvents.animal_product_collected.connect(_on_animal_product_collected)
	GameEvents.item_processed.connect(_on_item_processed)
	GameEvents.item_foraged.connect(_on_item_foraged)
	ShippingState.item_shipped.connect(_on_item_shipped)

func record(category: StringName, item_id: StringName, quantity: int = 1) -> int:
	if category == &"" or item_id == &"" or quantity <= 0:
		return get_count(category, item_id)
	var records := _get_records()
	var category_key := String(category)
	var item_key := String(item_id)
	var raw_category: Variant = records.get(category_key, {})
	var category_data: Dictionary = (raw_category as Dictionary).duplicate(true) if raw_category is Dictionary else {}
	var next := _safe_count(category_data.get(item_key, 0)) + quantity
	category_data[item_key] = next
	records[category_key] = category_data
	_set_records(records)
	collection_changed.emit(category, item_id, next)
	return next

func get_count(category: StringName, item_id: StringName) -> int:
	var records := _get_records()
	var category_data: Variant = records.get(String(category), {})
	if not category_data is Dictionary:
		return 0
	return _safe_count((category_data as Dictionary).get(String(item_id), 0))

func is_discovered(category: StringName, item_id: StringName) -> bool:
	return get_count(category, item_id) > 0

func get_discovered_count(category: StringName) -> int:
	var count := 0
	for item_id: StringName in get_total_ids(category):
		if is_discovered(category, item_id):
			count += 1
	return count

func get_total_ids(category: StringName) -> Array[StringName]:
	var ids: Dictionary = {}
	match category:
		CROPS:
			for crop: CropData in CropData.find_all():
				if crop != null and crop.harvest_item_id != &"":
					ids[String(crop.harvest_item_id)] = true
		FISH:
			for fish: FishData in FishData.find_all():
				if fish != null and fish.item_id != &"":
					ids[String(fish.item_id)] = true
		MINERALS:
			for node: MiningNodeData in MiningNodeData.find_all():
				if node != null and node.drop_item_id != &"":
					ids[String(node.drop_item_id)] = true
		ANIMAL_PRODUCTS:
			for animal: FarmAnimalData in FarmAnimalData.find_all():
				if animal == null:
					continue
				if animal.product_item_id != &"":
					ids[String(animal.product_item_id)] = true
				if animal.premium_product_item_id != &"":
					ids[String(animal.premium_product_item_id)] = true
		PROCESSED:
			for recipe: ProcessingRecipeData in ProcessingRecipeData.find_all():
				if recipe != null and recipe.output_item_id != &"":
					ids[String(recipe.output_item_id)] = true
		FORAGE:
			for forage: ForageEntryData in ForageEntryData.find_all():
				if forage != null and forage.item_id != &"":
					ids[String(forage.item_id)] = true
		SHIPPED:
			for item: ItemData in ItemData.find_all():
				if item != null and item.sell_price > 0 and item.kind != ItemData.Kind.TOOL and item.kind != ItemData.Kind.QUEST:
					ids[String(item.id)] = true
	var result: Array[StringName] = []
	var keys: Array[String] = []
	for raw_id: Variant in ids.keys():
		keys.append(String(raw_id))
	keys.sort()
	for key: String in keys:
		result.append(StringName(key))
	return result

func get_category_entries(category: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: StringName in get_total_ids(category):
		var item := ItemData.find(item_id)
		result.append({
			"id": String(item_id),
			"display_name": item.display_name if item != null else String(item_id).capitalize(),
			"count": get_count(category, item_id),
			"discovered": is_discovered(category, item_id),
		})
	return result

func get_summary() -> String:
	var parts := PackedStringArray()
	for category: StringName in CATEGORIES:
		parts.append("%s %d/%d" % [get_category_name(category), get_discovered_count(category), get_total_ids(category).size()])
	return " · ".join(parts)

func get_category_name(category: StringName) -> String:
	match category:
		CROPS: return tr("Crops")
		FISH: return tr("Fish")
		MINERALS: return tr("Mining")
		ANIMAL_PRODUCTS: return tr("Animals")
		PROCESSED: return tr("Processed")
		FORAGE: return tr("Forage")
		SHIPPED: return tr("Shipped")
		_: return String(category).capitalize()

func clear() -> void:
	WorldState.erase(STATE_KEY)

func _get_records() -> Dictionary:
	var raw: Variant = WorldState.get_value(STATE_KEY, {})
	return raw.duplicate(true) if raw is Dictionary else {}

func _set_records(records: Dictionary) -> void:
	WorldState.set_value(STATE_KEY, records.duplicate(true))

func _safe_count(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	return maxi(int(value), 0)

func _on_crop_harvested(_crop_id: StringName, item_id: StringName, quantity: int) -> void:
	record(CROPS, item_id, maxi(quantity, 1))

func _on_fish_caught(_fish_id: StringName, item_id: StringName) -> void:
	record(FISH, item_id, 1)

func _on_resource_mined(_node_id: StringName, item_id: StringName, quantity: int) -> void:
	record(MINERALS, item_id, maxi(quantity, 1))

func _on_animal_product_collected(_animal_id: StringName, item_id: StringName, quantity: int) -> void:
	record(ANIMAL_PRODUCTS, item_id, maxi(quantity, 1))

func _on_item_processed(_recipe_id: StringName, item_id: StringName, quantity: int) -> void:
	record(PROCESSED, item_id, maxi(quantity, 1))

func _on_item_foraged(item_id: StringName, quantity: int) -> void:
	record(FORAGE, item_id, maxi(quantity, 1))

func _on_item_shipped(item_id: StringName, quantity: int, _value: int) -> void:
	record(SHIPPED, item_id, maxi(quantity, 1))
