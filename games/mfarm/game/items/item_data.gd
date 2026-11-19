class_name MFarmItemData
extends ContentEntry

## One kind of thing the player can hold: a seed, a harvest, a tool, a
## blueprint, or scenery the player reaps (grass) that never goes in the bag.

enum ItemType {
	SEED,
	COMMODITY,
	FURNITURE,
	HOE_TOOL,
	CHOP_TOOL,
	BREAK_TOOL,
	REAP_TOOL,
	WATER_TOOL,
	COLLECT_TOOL,
	REAPABLE_SCENERY,
}

const KIND := &"mfarm_item"
## The most of one item a bag slot holds.
const MAX_STACK := 999

@export var display_name: String
@export_multiline var description: String
@export var item_type: ItemType = ItemType.COMMODITY
@export var icon: Texture2D
## How it looks on the ground and held over the player's head.
@export var world_sprite: Texture2D
## How many cells from the player the item reaches.
@export_range(0, 10) var use_radius := 0
@export var can_pick_up := true
@export var can_drop := false
@export var can_carry := false
@export_range(0, 999999) var price := 0
## The share of the price a shop pays for it.
@export_range(0.0, 1.0, 0.01) var sell_percentage := 0.0

static func find(entry_id: StringName) -> MFarmItemData:
	if entry_id == &"" or ContentRegistry.active == null:
		return null
	return ContentRegistry.active.get_entry(KIND, entry_id) as MFarmItemData

static func find_all() -> Array[MFarmItemData]:
	var result: Array[MFarmItemData] = []
	for entry: ContentEntry in ContentRegistry.active.get_entries(KIND):
		result.append(entry as MFarmItemData)
	return result

func is_tool() -> bool:
	return item_type in [ItemType.HOE_TOOL, ItemType.CHOP_TOOL, ItemType.BREAK_TOOL, ItemType.REAP_TOOL, ItemType.WATER_TOOL, ItemType.COLLECT_TOOL]

## What a shop pays for one.
func get_sell_price() -> int:
	return int(price * sell_percentage)

## The sprite drawn for it in the world: its world sprite, else its icon.
func get_world_texture() -> Texture2D:
	return world_sprite if world_sprite != null else icon

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if icon == null:
		problems.append("has no icon")
	return problems
