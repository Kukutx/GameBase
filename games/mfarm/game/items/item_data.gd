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
## What each kind of item sounds like when used, as the old game's did: a
## seed going in, the hoe, the watering can, the axe, the pickaxe, the basket
## and the sickle.
const USE_SOUNDS: Dictionary[ItemType, StringName] = {
	ItemType.SEED: &"sfx_plant",
	ItemType.HOE_TOOL: &"sfx_hoe",
	ItemType.WATER_TOOL: &"sfx_water",
	ItemType.CHOP_TOOL: &"sfx_axe",
	ItemType.BREAK_TOOL: &"sfx_pickaxe",
	ItemType.COLLECT_TOOL: &"sfx_basket",
	ItemType.REAP_TOOL: &"sfx_reap",
}

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
## The sound cue it plays when used, if not its kind's (USE_SOUNDS). A crop
## with a sound of its own sounds that instead, as the old game's notes asked:
## a tool has its sound, and a crop can have another.
@export var use_sound_cue_id: StringName

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

## The sound it makes when used: its own, else its kind's (none for a
## harvest or a blueprint).
func get_use_sound() -> StringName:
	return use_sound_cue_id if use_sound_cue_id != &"" else USE_SOUNDS.get(item_type, &"")

## What a shop pays for one.
func get_sell_price() -> int:
	return int(price * sell_percentage)

## The sprite drawn for it in the world: its world sprite, else its icon.
func get_world_texture() -> Texture2D:
	return world_sprite if world_sprite != null else icon

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if icon == null:
		problems.append("has no icon")
	if use_sound_cue_id != &"":
		problems.append_array(AudioCueData.find_reference_problems(registry, "use sound", use_sound_cue_id, AudioCueData.CueType.SFX))
	return problems
