class_name JianghuFoeData
extends ContentEntry

## Someone the hero fights while roaming. Their strength comes from where they
## are met (`JianghuRules.foe_stats()`); these scale it.

const KIND := &"jianghu_foe"

@export var display_name: String
@export var attack_scale := 1.0
@export var health_scale := 1.0
@export var silver_scale := 1.0
## The colour of their robe in the fight picture.
@export var robe := Color(0.25, 0.22, 0.2)

static func find(entry_id: StringName) -> JianghuFoeData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as JianghuFoeData

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if attack_scale <= 0.0 or health_scale <= 0.0 or silver_scale < 0.0:
		problems.append("has a scale that is not positive")
	return problems
