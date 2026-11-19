class_name JianghuRealmData
extends ContentEntry

## A realm of cultivation. The hero climbs `JianghuRules.LAYERS` layers of
## each realm with cultivation; to break into the next realm they must also
## have beaten the boss of the region (`gate_region_id`) of this one.

const KIND := &"jianghu_realm"

@export var display_name: String
@export var description: String
## The realm's place in the climb, from 0.
@export var order := 0
## The region whose boss must fall before the hero can leave this realm.
@export var gate_region_id: StringName
## The colour of the hero's aura in this realm.
@export var aura := Color(1.0, 0.85, 0.4)

static func find(entry_id: StringName) -> JianghuRealmData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as JianghuRealmData

## Every realm, in `order`.
static func find_all() -> Array[JianghuRealmData]:
	var result: Array[JianghuRealmData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	result.sort_custom(func(a: JianghuRealmData, b: JianghuRealmData) -> bool: return a.order < b.order)
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if gate_region_id != &"" and registry.get_entry(JianghuRegionData.KIND, gate_region_id) == null:
		problems.append("references unknown region '%s'" % gate_region_id)
	return problems
