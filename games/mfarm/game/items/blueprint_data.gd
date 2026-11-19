class_name MFarmBlueprintData
extends ContentEntry

## What building the furniture of a blueprint item takes: its id is the
## blueprint item's, `resources[i]` is needed `amounts[i]` times.

const KIND := &"mfarm_blueprint"

@export var resources: Array[StringName] = []
@export var amounts: PackedInt32Array = PackedInt32Array()
## The furniture placed when it is built.
@export var scene: PackedScene

static func find(entry_id: StringName) -> MFarmBlueprintData:
	if entry_id == &"" or ContentRegistry.active == null:
		return null
	return ContentRegistry.active.get_entry(KIND, entry_id) as MFarmBlueprintData

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not registry.has_entry(MFarmItemData.KIND, id):
		problems.append("is for unknown item '%s'" % id)
	if resources.size() != amounts.size():
		problems.append("lists %d resources but %d amounts" % [resources.size(), amounts.size()])
	for item: StringName in resources:
		if not registry.has_entry(MFarmItemData.KIND, item):
			problems.append("needs unknown item '%s'" % item)
	if scene == null:
		problems.append("has no scene")
	return problems
