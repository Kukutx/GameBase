class_name AnimalOffer
extends ShopOffer

## A farm animal a shop sells. It moves into free housing at the location the
## player shops at.

@export var animal_id: StringName

func get_key() -> String:
	return "animal:%s" % animal_id

func get_label(context: Dictionary) -> String:
	var animal := FarmAnimalData.find(animal_id)
	if animal == null:
		return String(animal_id)
	var location_id: StringName = context.get("location_id", &"")
	var slots := AnimalState.get_available_slots(location_id, animal.housing_type) if location_id != &"" else 0
	return tr("Buy %s — %dg  ·  %s slots %d") % [tr(animal.display_name), animal.purchase_price, tr(String(animal.housing_type).capitalize()), slots]

func can_buy(context: Dictionary) -> bool:
	var location_id: StringName = context.get("location_id", &"")
	return location_id != &"" and AnimalState.can_purchase(animal_id, location_id)

func buy(context: Dictionary) -> bool:
	var location_id: StringName = context.get("location_id", &"")
	return location_id != &"" and AnimalState.purchase(animal_id, location_id) != &""

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	if not registry.has_entry(FarmAnimalData.KIND, animal_id):
		return PackedStringArray(["sells unknown animal '%s'" % animal_id])
	return PackedStringArray()
