class_name MFarmBagData
extends ContentEntry

## What a bag holds when a new game starts: the player's bag, a box's or a
## shop's stock. `items[i]` and `amounts[i]` fill slot i; an empty id is an
## empty slot.

const KIND := &"mfarm_bag"

@export_range(1, 99) var slot_count := 8
@export var items: Array[StringName] = []
@export var amounts: PackedInt32Array = PackedInt32Array()

static func find(entry_id: StringName) -> MFarmBagData:
	if entry_id == &"" or ContentRegistry.active == null:
		return null
	return ContentRegistry.active.get_entry(KIND, entry_id) as MFarmBagData

## The bag's slots as [{"item": StringName, "amount": int}], `slot_count` long.
func make_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for index: int in slot_count:
		var item: StringName = items[index] if index < items.size() else &""
		var amount: int = amounts[index] if index < amounts.size() else 0
		if item == &"" or amount <= 0:
			slots.append({"item": &"", "amount": 0})
		else:
			slots.append({"item": item, "amount": amount})
	return slots

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if items.size() > slot_count:
		problems.append("lists more items than it has slots")
	if items.size() != amounts.size():
		problems.append("lists %d items but %d amounts" % [items.size(), amounts.size()])
	for item: StringName in items:
		if item != &"" and not registry.has_entry(MFarmItemData.KIND, item):
			problems.append("holds unknown item '%s'" % item)
	return problems
