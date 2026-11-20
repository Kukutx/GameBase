class_name MiningNodeData
extends ContentEntry

## A kind of rock the player breaks with a pick (`MiningNode`, tools of the
## `mine` action): it takes `durability` worn down by the tool's power, asks a
## tool of `required_tool_power` and spends energy each hit, drops its item,
## comes back after `respawn_days`, and in a mine appears from
## `minimum_mine_floor` down (`MineRockTier`).

const KIND := &"mining_node"

## The name the player reads.
@export var display_name: String = "Rock"
## How much it takes to break: each hit wears off the pick's power.
@export_range(1, 999, 1) var durability := 3
## The first floor of a mine it appears on (`MineRockTier`).
@export_range(1, 120, 1) var minimum_mine_floor := 1
## The power a pick needs (`ItemData.tool_power`) to hit it at all.
@export_range(1, 20, 1) var required_tool_power := 1
## The energy each hit spends, before the energy stats.
@export_range(0, 100, 1) var energy_cost := 3
## The item (`ItemData`) it gives once broken, and how many.
@export var drop_item_id: StringName
@export_range(1, 99, 1) var drop_quantity := 1
## How many days after it breaks it comes back.
@export_range(1, 28, 1) var respawn_days := 1
## The colour it is drawn in.
@export var visual_color := Color(0.48, 0.48, 0.50, 1.0)

## The mining node with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> MiningNodeData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as MiningNodeData

## The running game's mining nodes, sorted by id.
static func find_all() -> Array[MiningNodeData]:
	var result: Array[MiningNodeData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	if not ItemData.has_tagged(registry, drop_item_id, "mined"):
		return PackedStringArray(["drop '%s' is no item tagged mined" % drop_item_id])
	return PackedStringArray()
