class_name TownProjectData
extends ContentEntry

## A community project of the town (`TownProjectService`): the player donates
## the items it asks (`requirements`) until all are in, and then claims its
## reward. It opens once its prerequisites are complete, and content asks about
## it with `PROJECT_COMPLETED <project>`.

const KIND := &"town_project"

## The name the player reads.
@export var display_name: String = "Town Project"
## What the player reads of it.
@export_multiline var description: String
## The location (`WorldLocationData`) whose project board lists it.
@export var location_id: StringName
## The projects (`TownProjectData`) that must be complete before it opens.
@export var prerequisites: Array[StringName] = []
## What it asks the player to donate, as item id -> count.
@export var requirements: Dictionary = {}
## What claiming it once complete gives: money and items (item id -> count).
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}

## The town project with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> TownProjectData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as TownProjectData

## The running game's town projects, sorted by id.
static func find_all() -> Array[TownProjectData]:
	var result: Array[TownProjectData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func get_required_quantity(item_id: StringName) -> int:
	var raw: Variant = requirements.get(String(item_id), 0)
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return 0
	return maxi(int(raw), 0)

func has_requirement(item_id: StringName) -> bool:
	return get_required_quantity(item_id) > 0

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not registry.has_entry(WorldLocationData.KIND, location_id):
		problems.append("references unknown location '%s'" % location_id)
	if requirements.is_empty():
		problems.append("has no material requirements")
	if reward_money < 0:
		problems.append("has negative reward money")
	problems.append_array(ItemData.find_amount_problems(requirements, registry, "requires", "requirement quantity"))
	problems.append_array(ItemData.find_amount_problems(reward_items, registry, "rewards", "reward quantity"))
	for prerequisite_id: StringName in prerequisites:
		if prerequisite_id == id or not registry.has_entry(KIND, prerequisite_id):
			problems.append("references invalid prerequisite '%s'" % prerequisite_id)
	return problems

## The prerequisite cycles of the town projects of `registry`. Registered by
## the progression module as a content check.
static func find_cycle_problems(registry: ContentRegistry) -> PackedStringArray:
	var graph: Dictionary = {}
	for project: TownProjectData in registry.get_entries(KIND):
		graph[String(project.id)] = project.prerequisites
	return ContentRegistry.find_dependency_cycles(graph, "town project")
