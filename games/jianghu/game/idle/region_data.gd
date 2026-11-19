class_name JianghuRegionData
extends ContentEntry

## A stretch of the jianghu the hero roams in order. The hero fights
## `JianghuRules.REGION_FIGHTS` of its foes, then its boss; beating the boss
## opens the next region.

const KIND := &"jianghu_region"

@export var display_name: String
@export var description: String
@export var order := 0
## The foes met along the way, by turns.
@export var foe_ids: Array[StringName] = []
@export var boss_id: StringName
## The sky and hills of the scenery while the hero roams here.
@export var sky := Color(0.93, 0.9, 0.82)
@export var hills := Color(0.35, 0.42, 0.4)

static func find(entry_id: StringName) -> JianghuRegionData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as JianghuRegionData

## Every region, in `order`.
static func find_all() -> Array[JianghuRegionData]:
	var result: Array[JianghuRegionData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	result.sort_custom(func(a: JianghuRegionData, b: JianghuRegionData) -> bool: return a.order < b.order)
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if foe_ids.is_empty():
		problems.append("has no foes")
	for foe_id: StringName in foe_ids + [boss_id]:
		if registry.get_entry(JianghuFoeData.KIND, foe_id) == null:
			problems.append("references unknown foe '%s'" % foe_id)
	return problems
