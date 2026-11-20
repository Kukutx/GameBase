class_name ItemData
extends ContentEntry

## Something the player can carry in the inventory (`InventoryState`), buy and
## sell (`ShopData`, `sell_price`), eat or drink (`restores`, `food_buff_id`),
## use as a tool or a weapon (`tool_action`, `tool_power`), sow (`crop_id`) or
## build (`placeable_id`), as its `kind` says. Content asks about it by id and
## by its `tags` (the condition `ITEM_TAG`).

## What the item is, which decides what the player can do with it.
enum Kind {
	MATERIAL,
	FOOD,
	## Sown to grow its `crop_id`.
	SEED,
	## Used for its `tool_action`; a tool never stacks and cannot be shipped.
	TOOL,
	CROP,
	GIFT,
	## Kept for a quest; it cannot be shipped.
	QUEST,
	## Built as its `placeable_id`.
	PLACEABLE,
	## Drunk rather than eaten: a potion restores and buffs as food does.
	POTION,
}

const KIND := &"item"


## The name the player reads.
@export var display_name: String
## What the player reads of it in the inventory and the shops.
@export_multiline var description: String
## How many one inventory slot holds; a tool's is 1.
@export_range(1, 999, 1) var max_stack := 99
@export var icon: Texture2D
@export var kind: Kind = Kind.MATERIAL
## What a shop asks for it where the shop's stock leaves the price to the item
## (a price of 0, `ShopData.stock`).
@export_range(0, 999999, 1) var buy_price := 0
## What a shop pays for it; 0, it cannot be sold.
@export_range(0, 999999, 1) var sell_price := 0
## What eating or drinking it restores, as vital id (`VitalData`) → amount.
@export var restores: Dictionary[StringName, int] = {}
## The food buff (`FoodBuffData`) eating or drinking it gives; empty, none.
@export var food_buff_id: StringName
## Words content asks about it by (`ITEM_TAG <item> <tag>`): a quest that counts
## every fish caught, the player's weapons whose hits lay an affliction
## (`AfflictionData.weapon_tag`), the items a new game carries over
## (`ItemInheritance.tags`).
@export var tags: PackedStringArray = PackedStringArray()
## What the tool does: an action some installed module or the game responds
## to. Whoever handles an action names it with a constant of its own (the
## module that tills soil names "till") and registers it
## (`register_tool_action()`); content checks reject a tool whose action
## nobody registered.
@export var tool_action: StringName
## How strong the tool is: the damage a weapon deals before the player's
## stats (`WeaponUse`), the rocks a pick breaks and how fast
## (`MiningNodeData.required_tool_power`), the energy a hoe or a watering can
## spends on a plot (divided by it); a better tool raises it
## (`ToolUpgradeData`).
@export_range(1, 999, 1) var tool_power := 1
## The crop (`CropData`) a seed grows.
@export var crop_id: StringName
## The placeable (`PlaceableData`) a placeable item builds.
@export var placeable_id: StringName

## Tool actions registered with `register_tool_action()`, as action -> true.
static var _tool_actions: Dictionary = {}

## The item with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> ItemData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as ItemData

## The running game's items, sorted by id.
static func find_all() -> Array[ItemData]:
	var result: Array[ItemData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Declares that some installed module or the game handles tools with `action`.
## Called from `GameModule.install()`.
static func register_tool_action(action: StringName) -> void:
	_tool_actions[action] = true

## Problems of `amounts` (item id -> count) for a `find_problems()`: an id that
## is no item of `registry`, or a count that is not a positive integer. `verb`
## says what the entry does with the items ("rewards"), `noun` what the counts
## are ("reward quantity").
static func find_amount_problems(amounts: Dictionary, registry: ContentRegistry, verb: String, noun: String) -> PackedStringArray:
	var problems := PackedStringArray()
	for raw_id: Variant in amounts:
		if not registry.has_entry(KIND, StringName(String(raw_id))):
			problems.append("%s unknown item '%s'" % [verb, raw_id])
		elif typeof(amounts[raw_id]) != TYPE_INT or int(amounts[raw_id]) <= 0:
			problems.append("has invalid %s for '%s'" % [noun, raw_id])
	return problems

## Whether `item_id` names an item of `registry` that has `tag`.
static func has_tagged(registry: ContentRegistry, item_id: StringName, tag: String) -> bool:
	var item := registry.get_entry(KIND, item_id) as ItemData
	return item != null and item.has_tag(tag)

func is_tool() -> bool:
	return kind == Kind.TOOL and tool_action != &""

func is_seed() -> bool:
	return kind == Kind.SEED and crop_id != &""

func is_placeable() -> bool:
	return kind == Kind.PLACEABLE and placeable_id != &""

func is_edible() -> bool:
	return not restores.is_empty() or food_buff_id != &""

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if kind == Kind.TOOL:
		if not _tool_actions.has(tool_action):
			problems.append("is a tool with action '%s', which no installed module or the game handles" % tool_action)
		if max_stack != 1:
			problems.append("is a tool and must have max_stack 1")
	elif tool_action != &"":
		problems.append("is not a tool but has tool action '%s'" % tool_action)
	if kind != Kind.SEED and crop_id != &"":
		problems.append("is not a seed but names crop '%s'" % crop_id)
	if kind == Kind.PLACEABLE:
		var placeable := registry.get_entry(PlaceableData.KIND, placeable_id) as PlaceableData
		if placeable == null:
			problems.append("references unknown placeable '%s'" % placeable_id)
	elif placeable_id != &"":
		problems.append("is not a placeable but names placeable '%s'" % placeable_id)
	if food_buff_id != &"" and not registry.has_entry(FoodBuffData.KIND, food_buff_id):
		problems.append("references unknown food buff '%s'" % food_buff_id)
	for vital_id: StringName in restores:
		if not registry.has_entry(VitalData.KIND, vital_id):
			problems.append("restores unknown vital '%s'" % vital_id)
		elif restores[vital_id] <= 0:
			problems.append("restores no %s" % vital_id)
	return problems
