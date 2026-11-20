class_name CollectionMilestoneData
extends ContentEntry

## A reward of the player's collection log (`CollectionService`): for having
## discovered a number of the items of a `category` (harvested, caught, mined,
## ...), or for having claimed every one of its `prerequisites`. The player
## claims its reward once it is ready (`CollectionMilestoneService`).

const KIND := &"collection_milestone"

## The name the player reads.
@export var display_name: String
## What the player reads of it.
@export_multiline var description: String
## The collection it counts (`CollectionService.CATEGORIES`: harvested,
## caught, ...); empty, it counts its `prerequisites` instead.
@export var category: StringName
## How many of the category's items must be discovered; 0, all it holds.
@export_range(0, 999, 1) var required_discovered := 0
## The milestones (`CollectionMilestoneData`) that must be claimed first.
@export var prerequisites: Array[StringName] = []
## What claiming it gives: money and items (item id -> count).
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}

## The collection milestone with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> CollectionMilestoneData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as CollectionMilestoneData

## The running game's collection milestones, sorted by id.
static func find_all() -> Array[CollectionMilestoneData]:
	var result: Array[CollectionMilestoneData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func get_required_count() -> int:
	if category == &"":
		return prerequisites.size()
	if required_discovered > 0:
		return required_discovered
	return CollectionState.get_total_count(category)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if category == &"" and prerequisites.is_empty():
		problems.append("has no progress condition")
	elif category != &"" and not CollectionService.CATEGORIES.has(category):
		problems.append("references unknown category '%s'" % category)
	if required_discovered < 0:
		problems.append("has negative discovered requirement")
	if reward_money < 0:
		problems.append("has negative reward money")
	problems.append_array(ItemData.find_amount_problems(reward_items, registry, "rewards", "reward quantity"))
	for prerequisite_id: StringName in prerequisites:
		if prerequisite_id == id or not registry.has_entry(KIND, prerequisite_id):
			problems.append("references invalid prerequisite '%s'" % prerequisite_id)
	return problems

## The prerequisite cycles of the collection milestones of `registry`.
## Registered by the progression module as a content check.
static func find_cycle_problems(registry: ContentRegistry) -> PackedStringArray:
	var graph: Dictionary = {}
	for milestone: CollectionMilestoneData in registry.get_entries(KIND):
		graph[String(milestone.id)] = milestone.prerequisites
	return ContentRegistry.find_dependency_cycles(graph, "collection milestone")
