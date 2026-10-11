class_name ToolUpgradeData
extends ContentEntry

const KIND := &"tool_upgrade"

@export var display_name: String
@export var source_item_id: StringName
@export var result_item_id: StringName
@export var materials: Dictionary = {}
@export_range(0, 999999, 1) var money_cost := 0
## When the upgrade is offered, as a `GameRules` query; empty: always.
@export var condition := ""

## The tool upgrade with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> ToolUpgradeData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as ToolUpgradeData

## The running game's tool upgrades, sorted by id.
static func find_all() -> Array[ToolUpgradeData]:
	var result: Array[ToolUpgradeData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func meets_requirements(inventory: InventoryStore = InventoryState) -> bool:
	if inventory == null or source_item_id == &"" or result_item_id == &"" or money_cost < 0:
		return false
	if not inventory.has_item(source_item_id, 1):
		return false
	if PlayerState.money < money_cost:
		return false
	if not GameRules.check(condition):
		return false
	return inventory.can_apply_transaction(materials, {})

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var source := registry.get_entry(ItemData.KIND, source_item_id) as ItemData
	var result := registry.get_entry(ItemData.KIND, result_item_id) as ItemData
	for pair: Array in [[source_item_id, source], [result_item_id, result]]:
		if pair[1] == null:
			problems.append("references unknown tool '%s'" % pair[0])
		elif not (pair[1] as ItemData).is_tool():
			problems.append("'%s' is not a usable tool" % pair[0])
	if source != null and result != null and source.is_tool() and result.is_tool():
		if source.tool_action != result.tool_action:
			problems.append("changes tool action from '%s' to '%s'" % [source.tool_action, result.tool_action])
		if result.tool_power <= source.tool_power:
			problems.append("result power %d does not exceed source power %d" % [result.tool_power, source.tool_power])
	if money_cost < 0:
		problems.append("has negative money cost")
	problems.append_array(ItemData.find_amount_problems(materials, registry, "requires", "material quantity"))
	return problems
