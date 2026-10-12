class_name BattleActionData
extends ContentEntry

## What a unit can do on its turn in a grid battle (`BattleUnitData.action_ids`):
## a strike, a shot, a spell that hits an area, a heal. It aims at a cell from
## `min_range` to `max_range` steps from the unit (`BattleGrid.distance()`) and
## reaches the units within `area` steps of that cell that it affects: those
## hostile to the user's side when it does damage, those of the user's side,
## the user too, when it heals. It never hurts its own side.

const KIND := &"battle_action"

enum Effect {
	## Takes health: its power and the user's attack, less the target's defense,
	## at least 1.
	DAMAGE,
	## Gives back health: its power.
	HEAL,
}

@export var display_name := ""
@export var effect := Effect.DAMAGE
@export_range(0, 999) var power := 4
## How near and how far the cell it aims at may be, in steps; 0 is the user's
## own cell.
@export_range(0, 12) var min_range := 1
@export_range(0, 12) var max_range := 1
## How many steps from the aimed cell it reaches too; 0: that cell alone.
@export_range(0, 4) var area := 0

## The action with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> BattleActionData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as BattleActionData

## The running game's actions, sorted by id.
static func find_all() -> Array[BattleActionData]:
	var result: Array[BattleActionData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Whether it affects a unit of faction `target` when a unit of faction `user`
## takes it.
func affects(user: StringName, target: StringName) -> bool:
	var hostile := FactionData.are_hostile(user, target)
	return hostile if effect == Effect.DAMAGE else not hostile

## What it takes from or gives to `target` when `user` takes it.
func amount_for(user: GridUnit, target: GridUnit) -> int:
	if effect == Effect.HEAL:
		return power
	return maxi(power + user.data.attack - target.data.defense, 1)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if min_range > max_range:
		problems.append("has a min range %d above its max range %d" % [min_range, max_range])
	if effect == Effect.DAMAGE and max_range == 0 and area == 0:
		problems.append("does damage only to its user's cell")
	return problems
