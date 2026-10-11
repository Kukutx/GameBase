class_name FarmExpansionData
extends ContentEntry

const KIND := &"farm_expansion"

@export var display_name: String = "Farm Expansion"
@export_multiline var description: String
@export var housing_id: StringName
@export_range(1, 32, 1) var capacity_after := 8
@export_range(0, 999999, 1) var money_cost := 0
@export var materials: Dictionary = {}
@export var prerequisites: Array[StringName] = []
## When the expansion is offered once its prerequisites are built, in the
## `GameQuery` syntax (`PROJECT_COMPLETED barn_fund`); empty means always.
@export var condition: String = ""

## The farm expansion with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FarmExpansionData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FarmExpansionData

## The running game's farm expansions, sorted by id.
static func find_all() -> Array[FarmExpansionData]:
	var result: Array[FarmExpansionData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func has_valid_cost() -> bool:
	return money_cost > 0 or not materials.is_empty()

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if housing_id == &"":
		problems.append("has no housing id")
	if capacity_after <= 0:
		problems.append("has invalid target capacity %d" % capacity_after)
	if money_cost < 0:
		problems.append("has negative money cost")
	if not has_valid_cost():
		problems.append("has no cost")
	problems.append_array(ItemData.find_amount_problems(materials, registry, "requires", "material quantity"))
	for prerequisite_id: StringName in prerequisites:
		var prerequisite := registry.get_entry(KIND, prerequisite_id) as FarmExpansionData
		if prerequisite == null or prerequisite == self:
			problems.append("references invalid prerequisite '%s'" % prerequisite_id)
		elif prerequisite.housing_id != housing_id:
			problems.append("depends on '%s' from different housing '%s'" % [prerequisite_id, prerequisite.housing_id])
		elif prerequisite.capacity_after >= capacity_after:
			problems.append("capacity %d does not exceed prerequisite '%s' capacity %d" % [capacity_after, prerequisite_id, prerequisite.capacity_after])
	for other: FarmExpansionData in registry.get_entries(KIND):
		if String(other.id) < String(id) and other.housing_id == housing_id and other.capacity_after == capacity_after:
			problems.append("shares housing '%s' capacity %d with '%s'" % [housing_id, capacity_after, other.id])
	return problems

## The prerequisite cycles of the farm expansions of `registry`. Registered by
## the lifesim module as a content check.
static func find_cycle_problems(registry: ContentRegistry) -> PackedStringArray:
	var graph: Dictionary = {}
	for expansion: FarmExpansionData in registry.get_entries(KIND):
		graph[String(expansion.id)] = expansion.prerequisites
	return ContentRegistry.find_dependency_cycles(graph, "farm expansion")
