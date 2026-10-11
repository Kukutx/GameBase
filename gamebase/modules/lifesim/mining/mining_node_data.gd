class_name MiningNodeData
extends ContentEntry

const KIND := &"mining_node"

@export var display_name: String = "Rock"
@export_range(1, 999, 1) var durability := 3
@export_range(1, 120, 1) var minimum_mine_floor := 1
@export_range(1, 20, 1) var required_tool_power := 1
@export_range(0, 100, 1) var energy_cost := 3
@export var drop_item_id: StringName
@export_range(1, 99, 1) var drop_quantity := 1
@export_range(1, 28, 1) var respawn_days := 1
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
	if not ItemData.has_tagged(registry, drop_item_id, "mining"):
		return PackedStringArray(["drop '%s' is no item tagged mining" % drop_item_id])
	return PackedStringArray()
