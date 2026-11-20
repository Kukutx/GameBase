class_name BattleActionData
extends ContentEntry

## What a unit can do on its turn in a grid battle (`BattleUnitData.action_ids`):
## a strike, a shot, a spell that hits an area, a heal. It aims at a cell from
## `min_range` to `max_range` steps from the unit (`BattleGrid.distance()`) and
## reaches the units within `area` steps of that cell that it affects: those
## hostile to the user's side when it does damage, those of the user's side,
## the user too, when it heals. It never hurts its own side. A strong one may
## need to recharge (`recharge_turns`): its user then waits turns before it
## takes it again. One that does damage may also set back the time gauges of
## the foes it leaves standing (`delay`), so their turns come later. Any may
## boost the attack or defense of the units it reaches and leaves standing
## (`boosts`) for some of their turns: a blessing on its own side, a curse on
## its foes. One that does damage may lay an affliction on the foes it leaves
## standing (`affliction_id`), a poison that takes their health on its ticks in
## battle time.

const KIND := &"battle_action"

enum Effect {
	## Takes health: its power and the user's attack, less the target's defense
	## (each with its boosts, `GridUnit.get_attack()`), at least 1.
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
## How many of its user's turns go by after it takes it before it may take it
## again; 0: on every turn.
@export_range(0, 9) var recharge_turns := 0
## How far it sets back the time gauge of each foe it hits and leaves standing
## (`AtbBattle.GAUGE_FULL` is a whole turn), no further than empty; 0: not at
## all. Only an action that does damage delays.
@export_range(0.0, 100.0, 5.0) var delay := 0.0
## How it changes the attack and defense (`GridUnit.ATTACK`,
## `GridUnit.DEFENSE`) of each unit it reaches and leaves standing, as stat ->
## amount, through that unit's next `boost_turns` turns
## (`GridUnit.boost()`): more on its own side when it heals, less on its foes
## when it does damage; empty, none.
@export var boosts: Dictionary[StringName, int] = {}
@export_range(1, 9) var boost_turns := 2
## What it lays on each foe it hits and leaves standing (`AfflictionData`,
## `GridUnit.afflict()`): a poisoned dart; empty, nothing. Only an action that
## does damage lays one.
@export var affliction_id: StringName

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
	return maxi(power + user.get_attack() - target.get_defense(), 1)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if affliction_id != &"" and not registry.has_entry(AfflictionData.KIND, affliction_id):
		problems.append("lays unknown affliction '%s'" % affliction_id)
	elif affliction_id != &"" and effect == Effect.HEAL:
		problems.append("lays an affliction on the units it heals")
	if display_name.is_empty():
		problems.append("has no display name")
	if min_range > max_range:
		problems.append("has a min range %d above its max range %d" % [min_range, max_range])
	if effect == Effect.DAMAGE and max_range == 0 and area == 0:
		problems.append("does damage only to its user's cell")
	if effect == Effect.HEAL and delay > 0.0:
		problems.append("delays the units it heals")
	for stat: StringName in boosts:
		if stat != GridUnit.ATTACK and stat != GridUnit.DEFENSE:
			problems.append("boosts unknown stat '%s'" % stat)
		elif boosts[stat] == 0:
			problems.append("boosts %s by 0" % stat)
		elif effect == Effect.HEAL and boosts[stat] < 0:
			problems.append("lowers the %s of its own side" % stat)
		elif effect == Effect.DAMAGE and boosts[stat] > 0:
			problems.append("raises the %s of its foes" % stat)
	return problems
