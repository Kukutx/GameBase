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
## What parts the effects of an item where they share a line
## (`describe_effects()`).
const EFFECT_SEPARATOR := " · "


## The name the player reads.
@export var display_name: String
## What the player reads of it in the inventory and the shops, above what it
## does (`describe_effects()`): what it is, not what it does again.
@export_multiline var description: String
## How many one inventory slot holds; a tool's is 1.
@export_range(1, 999, 1) var max_stack := 99
## The picture of it a game's own menus show (MFarm's bag and trade panel).
@export var icon: Texture2D
## What it is, which decides what the player can do with it.
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
## What the player may need an item for now besides what it restores and its
## food buff, registered with `register_consume_need()`.
static var _consume_needs: Array[Callable] = []
## The texts registered with `register_effect_text()`.
static var _effect_texts: Array[Callable] = []

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

## Declares a use some installed module or the game makes of an item the
## player eats or drinks, beyond what it restores and its food buff: `need`
## takes the item and says whether the player has that use for it now (the
## combat module's: it lifts an affliction on them). Eating one the player
## has no use for is refused. Called from `GameModule.install()`.
static func register_consume_need(need: Callable) -> void:
	if not _consume_needs.has(need):
		_consume_needs.append(need)

## Declares what some installed module or the game tells of what an item does,
## beyond what it restores and its food buff: `text` takes the item and
## returns the lines the player reads (the combat module's: how hard a weapon
## hits, what an item cures). Called from `GameModule.install()`.
static func register_effect_text(text: Callable) -> void:
	if not _effect_texts.has(text):
		_effect_texts.append(text)

## What a menu tells of it under its list (a shop's counter, a crafting
## station): its description, then what it does (`describe_effects()`) on a
## line of its own; "" for neither.
func describe() -> String:
	var parts := PackedStringArray()
	if not description.is_empty():
		parts.append(TranslationServer.translate(description))
	var effects := describe_effects()
	if not effects.is_empty():
		parts.append(EFFECT_SEPARATOR.join(effects))
	return "\n".join(parts)

## What it does, as the player reads it before buying or using it (a shop, the
## pause menu's Items): what it restores ("Restores 35 Health"), its food buff
## and what that changes, then what the modules and the game tell of it
## (`register_effect_text()`).
func describe_effects() -> PackedStringArray:
	var effects := PackedStringArray()
	var restored := PackedStringArray()
	for vital_id: StringName in restores:
		var vital := VitalData.find(vital_id)
		if vital != null and restores[vital_id] > 0:
			restored.append("%d %s" % [restores[vital_id], tr(vital.display_name)])
	if not restored.is_empty():
		effects.append(tr("Restores %s") % GameText.list(restored))
	var buff: FoodBuffData = FoodBuffData.find(food_buff_id) if food_buff_id != &"" else null
	if buff != null:
		var changes := buff.describe_changes()
		if changes.is_empty():
			effects.append(tr("Gives %s") % tr(buff.display_name))
		else:
			effects.append(tr("Gives %s (%s)") % [tr(buff.display_name), changes])
	for text: Callable in _effect_texts:
		effects.append_array(text.call(self))
	return effects

## Whether a use registered with `register_consume_need()` wants the item now.
func is_needed_by_others() -> bool:
	for need: Callable in _consume_needs:
		if need.call(self):
			return true
	return false

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

## Whether the player can eat or drink it (`InventoryStore.consume()`): a
## potion, or what restores a vital or gives a food buff.
func is_edible() -> bool:
	return kind == Kind.POTION or not restores.is_empty() or food_buff_id != &""

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
	# The menus show the description above the effects: one that only says
	# what an effect says reads twice ("Restores 35 health." over "Restores
	# 35 Health"). Both are read as written, whatever the player's language.
	var translates := can_translate_messages()
	set_message_translation(false)
	var effects := describe_effects()
	set_message_translation(translates)
	var said := _plain(description)
	for effect: String in effects:
		if not said.is_empty() and _plain(effect) == said:
			problems.append("has a description that only repeats its effect '%s', which the menus show under it: tell what it is" % effect)
	return problems

# `text` as words to compare: lower case, without the stop at its end.
static func _plain(text: String) -> String:
	return text.strip_edges().trim_suffix(".").strip_edges().to_lower()
