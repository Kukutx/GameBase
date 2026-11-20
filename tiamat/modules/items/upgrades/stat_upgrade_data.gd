class_name StatUpgradeData
extends ContentEntry

## A lasting upgrade the player buys level by level, at a stand
## (`StatUpgradeStand`): each level changes stats (`multipliers` and
## `bonuses`, of stats an installed module or the game reads, once more for
## each level) for as long as the world lasts, across days and runs, and costs
## money (`money_costs`) and items (`materials`). Its level lives in the world
## (`stat_upgrade:<id>`), so it saves with it. Content asks about one with
## `STAT_UPGRADE_AT_LEAST <upgrade> <level>` and gives a level with
## `RAISE_STAT_UPGRADE <upgrade>`; `ItemsEvents.stat_upgraded` tells of each
## level. The world's upgrades are a `GameStats` source (`StatUpgrades`).

const KIND := &"stat_upgrade"
## The level of each upgrade: a world value `stat_upgrade:<upgrade id>`.
const LEVEL_PREFIX := "stat_upgrade:"

@export var display_name := ""
@export_multiline var description := ""
## When the player may buy its next level: a `GameRules` query; empty, always.
@export var condition := ""
## How many levels it has.
@export_range(1, 99, 1) var max_level := 1
## The money each level costs, from the first; a level past the end of the
## list costs as much as the last.
@export var money_costs: PackedInt32Array = PackedInt32Array()
## The items each level costs, as item id -> how many.
@export var materials: Dictionary[StringName, int] = {}
## Multiplier of each stat it changes, as stat -> factor, per level.
@export var multipliers: Dictionary[StringName, float] = {}
## Amount added to each stat it changes, as stat -> amount, per level.
@export var bonuses: Dictionary[StringName, float] = {}

## The upgrade with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> StatUpgradeData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as StatUpgradeData

## The running game's upgrades, sorted by id.
static func find_all() -> Array[StatUpgradeData]:
	var result: Array[StatUpgradeData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## The world value that keeps the level of upgrade `upgrade_id`.
static func level_key(upgrade_id: StringName) -> StringName:
	return StringName(LEVEL_PREFIX + String(upgrade_id))

## The level the world bought, from 0.
func get_level() -> int:
	return clampi(WorldState.get_int(level_key(id)), 0, max_level)

## Whether it reached `max_level`.
func is_maxed() -> bool:
	return get_level() >= max_level

## The money its next level costs; 0 once maxed.
func get_next_cost() -> int:
	if is_maxed() or money_costs.is_empty():
		return 0
	return maxi(money_costs[mini(get_level(), money_costs.size() - 1)], 0)

## What its next level costs, as the player reads it ("80g, Ember Core x1"),
## or "" when it costs nothing.
func describe_cost() -> String:
	var parts := PackedStringArray()
	var money := get_next_cost()
	if money > 0:
		parts.append(TranslationServer.translate("%dg") % money)
	for item_id: StringName in _sorted_materials():
		parts.append("%s x%d" % [GameRulesService.entry_name(ItemData.KIND, item_id), materials[item_id]])
	return ", ".join(parts)

## Why the player cannot buy its next level now, as they read it, or "" when
## they can: it is maxed, its condition does not hold (what it needs), or the
## player lacks the money or an item.
func get_buy_problem() -> String:
	if is_maxed():
		return TranslationServer.translate("Fully upgraded")
	if not GameRules.check(condition):
		return TranslationServer.translate("Locked: %s") % ", ".join(GameRules.describe(condition))
	if not Wallet.can_afford(get_next_cost()):
		return TranslationServer.translate("Needs: %s") % (TranslationServer.translate("%dg") % get_next_cost())
	for item_id: StringName in _sorted_materials():
		if not InventoryState.has_item(item_id, materials[item_id]):
			return TranslationServer.translate("Needs: %s") % ("%s x%d" % [GameRulesService.entry_name(ItemData.KIND, item_id), materials[item_id]])
	return ""

## Whether the player can buy its next level now.
func can_buy() -> bool:
	return get_buy_problem().is_empty()

## Buys its next level: takes what it costs and raises it; false, and nothing
## taken, when the player cannot (`get_buy_problem()`).
func buy() -> bool:
	if not can_buy():
		return false
	var cost := get_next_cost()
	if not Wallet.spend(cost):
		return false
	if not materials.is_empty() and not InventoryState.apply_transaction_atomic(materials, {}):
		Wallet.add(cost)
		return false
	return raise()

## Raises it one level without a cost (content gives one); false once maxed.
func raise() -> bool:
	if is_maxed():
		return false
	var level := get_level() + 1
	WorldState.set_value(level_key(id), level)
	ItemsEvents.stat_upgraded.emit(id, level)
	return true

## Its name as the player reads it.
func get_display_name() -> String:
	return TranslationServer.translate(display_name) if not display_name.is_empty() else String(id)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	if multipliers.is_empty() and bonuses.is_empty():
		problems.append("changes no stat")
	for cost: int in money_costs:
		if cost < 0:
			problems.append("costs less than nothing (%d)" % cost)
	if money_costs.size() > max_level:
		problems.append("lists %d money costs for %d levels" % [money_costs.size(), max_level])
	for item_id: StringName in materials:
		if registry.get_entry(ItemData.KIND, item_id) == null:
			problems.append("costs unknown item '%s'" % item_id)
		elif materials[item_id] < 1:
			problems.append("costs %d of '%s'" % [materials[item_id], item_id])
	problems.append_array(GameStats.find_change_problems(multipliers, bonuses))
	return problems

func _sorted_materials() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(materials.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids
