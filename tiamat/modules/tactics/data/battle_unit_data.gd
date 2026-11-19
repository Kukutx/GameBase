class_name BattleUnitData
extends ContentEntry

## A kind of unit that fights in grid battles (`BattleMapData.placements`): a
## soldier, an archer, a raider. Its gauge fills at `speed` (`AtbBattle`), and
## on its turn it walks up to `move` cells and takes one of its actions.

const KIND := &"battle_unit"

@export var display_name := ""
## What a cell shows of it; none: a disc of `color` with its name's initial.
@export var texture: Texture2D
@export var color := Color(0.55, 0.6, 0.7)
@export_range(1, 9999) var max_health := 20
## What it adds to the damage it does (`BattleActionData.amount_for()`).
@export_range(0, 999) var attack := 4
## What it takes off the damage it is done.
@export_range(0, 999) var defense := 1
## How fast its gauge fills, in points a second: a turn comes every
## `AtbBattle.GAUGE_FULL / speed` seconds.
@export_range(1.0, 100.0, 0.5) var speed := 20.0
## How many cells it walks on a turn.
@export_range(0, 12) var move := 3
## What it can do on its turn (`BattleActionData`), its plain attack first.
@export var action_ids: Array[StringName] = []

## The unit with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> BattleUnitData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as BattleUnitData

## The running game's units, sorted by id.
static func find_all() -> Array[BattleUnitData]:
	var result: Array[BattleUnitData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Its actions, in the order it lists them; unknown ids are left out.
func get_actions() -> Array[BattleActionData]:
	var result: Array[BattleActionData] = []
	for action_id: StringName in action_ids:
		var action := BattleActionData.find(action_id)
		if action != null:
			result.append(action)
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if speed <= 0.0:
		problems.append("has speed %s, not above 0" % speed)
	if action_ids.is_empty():
		problems.append("has no action")
	for action_id: StringName in action_ids:
		if not registry.has_entry(BattleActionData.KIND, action_id):
			problems.append("references unknown action '%s'" % action_id)
	return problems
