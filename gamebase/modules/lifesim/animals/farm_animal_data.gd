class_name FarmAnimalData
extends ContentEntry

const KIND := &"farm_animal"

@export var display_name: String = "Animal"
@export var sprite_path: String
@export var frame_size := Vector2i(32, 32)
@export_range(1, 60, 1) var animation_fps := 10
@export_range(0, 999, 1) var idle_from := 0
@export_range(0, 999, 1) var idle_to := 0
@export_range(0, 999, 1) var walk_from := 0
@export_range(0, 999, 1) var walk_to := 0
@export_range(0, 999, 1) var eat_from := 0
@export_range(0, 999, 1) var eat_to := 0
@export_range(1.0, 300.0, 1.0) var move_speed := 28.0
@export_range(8.0, 256.0, 1.0) var wander_radius := 56.0
@export var collision_size := Vector2(14, 10)
@export var visual_offset := Vector2.ZERO
@export_range(0.1, 4.0, 0.05) var visual_scale := 1.0
@export_group("Ownership")
## The kind of AnimalHousing the animal lives in (its housing_type).
@export var housing_type: StringName
@export_range(0, 999999, 1) var purchase_price := 500
## The item the animal eats, one a day.
@export var feed_item_id: StringName
@export_range(0, 100, 1) var missed_feed_happiness_loss := 3

@export_group("Production")
@export var product_item_id: StringName
@export var premium_product_item_id: StringName
@export_range(0, 100, 1) var premium_happiness_threshold := 80
@export_range(1, 99, 1) var product_quantity := 1
@export_range(1, 28, 1) var product_interval_days := 1
@export_range(0, 100, 1) var pet_happiness_gain := 5

## The farm animal with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FarmAnimalData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FarmAnimalData

## The running game's farm animals, sorted by id.
static func find_all() -> Array[FarmAnimalData]:
	var result: Array[FarmAnimalData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func has_valid_animation_ranges() -> bool:
	return idle_from <= idle_to and walk_from <= walk_to and eat_from <= eat_to

func get_product_item_id(happiness: int) -> StringName:
	if premium_product_item_id != &"" and happiness >= premium_happiness_threshold:
		return premium_product_item_id
	return product_item_id

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not has_valid_animation_ranges():
		problems.append("has invalid animation ranges")
	if frame_size.x <= 0 or frame_size.y <= 0:
		problems.append("has invalid frame size")
	if housing_type == &"":
		problems.append("has no housing type")
	if purchase_price <= 0:
		problems.append("has invalid purchase price")
	for product_id: StringName in [product_item_id, premium_product_item_id]:
		if product_id != &"" and not ItemData.has_tagged(registry, product_id, "animal_product"):
			problems.append("product '%s' is no item tagged animal_product" % product_id)
	if not ItemData.has_tagged(registry, feed_item_id, "animal_feed"):
		problems.append("feed '%s' is no item tagged animal_feed" % feed_item_id)
	return problems
