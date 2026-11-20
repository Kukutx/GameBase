extends RefCounted

## Fixture content for the tactics module's tests: a strike, a shot, a blast
## that reaches an area, a mend, a volley that recharges, a bash that
## delays, a rally that boosts, a hex that curses and a venom that poisons,
## the poison, and units that take them.
##
##     const TacticsFixture := preload("res://tiamat/modules/tactics/test/tactics_fixture.gd")

static func action(id: StringName, power: int, min_range := 1, max_range := 1, area := 0, heals := false, recharge := 0) -> BattleActionData:
	var entry := BattleActionData.new()
	entry.id = id
	entry.display_name = String(id).capitalize()
	entry.power = power
	entry.min_range = min_range
	entry.max_range = max_range
	entry.area = area
	entry.effect = BattleActionData.Effect.HEAL if heals else BattleActionData.Effect.DAMAGE
	entry.recharge_turns = recharge
	return entry

## A bash: a blow of 1 that sets back the gauge of the foe it leaves standing
## by half a turn.
static func bash() -> BattleActionData:
	var entry := action(&"fixture_bash", 1)
	entry.delay = 50.0
	return entry

## A rally: a call that gives its user and its side around it 2 more attack
## through their next two turns.
static func rally() -> BattleActionData:
	var entry := action(&"fixture_rally", 0, 0, 0, 1, true)
	entry.boosts = {GridUnit.ATTACK: 2}
	return entry

## A hex: a blow of 1 that takes 2 from the defense of the foe it leaves
## standing through its next three turns.
static func hex() -> BattleActionData:
	var entry := action(&"fixture_hex", 1)
	entry.boosts = {GridUnit.DEFENSE: -2}
	entry.boost_turns = 3
	return entry

## A poison: 1 health a second of battle time for four seconds.
static func poison() -> AfflictionData:
	var entry := AfflictionData.new()
	entry.id = &"fixture_poison"
	entry.display_name = "Fixture Poison"
	entry.seconds = 4.0
	entry.tick_seconds = 1.0
	entry.tick_damage = 1
	return entry

## A venom: a bite of no power but its user's attack that poisons the foe it
## leaves standing.
static func venom() -> BattleActionData:
	var entry := action(&"fixture_venom", 0)
	entry.affliction_id = &"fixture_poison"
	return entry

static func unit(id: StringName, health: int, attack: int, defense: int, speed: float, move: int, action_ids: Array[StringName]) -> BattleUnitData:
	var entry := BattleUnitData.new()
	entry.id = id
	entry.display_name = String(id).capitalize()
	entry.max_health = health
	entry.attack = attack
	entry.defense = defense
	entry.speed = speed
	entry.move = move
	entry.action_ids = action_ids
	return entry

## The fixture actions and units: a knight (fast, strong), an archer (shoots
## two or three cells away), a healer (mends one cell away or itself), a raider,
## a mage (blasts an area), a captain (strikes, or looses a volley over an
## area that then recharges for two of its turns) and a shield (strikes, or
## bashes for less and sets the foe's gauge back by half a turn) and a herald
## (strikes, rallies its side or hexes a foe) and an adder (strikes or
## poisons a foe), whose actions do the power plus the attack less the
## defense.
static func entries() -> Array:
	return [
		action(&"fixture_strike", 3),
		action(&"fixture_shot", 2, 2, 3),
		action(&"fixture_blast", 2, 1, 3, 1),
		action(&"fixture_mend", 5, 0, 1, 0, true),
		action(&"fixture_volley", 4, 2, 3, 1, false, 2),
		bash(),
		rally(),
		hex(),
		venom(),
		poison(),
		unit(&"fixture_knight", 20, 4, 2, 50.0, 3, [&"fixture_strike"]),
		unit(&"fixture_archer", 12, 3, 0, 25.0, 3, [&"fixture_shot"]),
		unit(&"fixture_healer", 10, 0, 0, 25.0, 3, [&"fixture_mend", &"fixture_strike"]),
		unit(&"fixture_raider", 12, 3, 1, 25.0, 3, [&"fixture_strike"]),
		unit(&"fixture_mage", 8, 2, 0, 20.0, 2, [&"fixture_blast"]),
		unit(&"fixture_captain", 18, 3, 1, 25.0, 2, [&"fixture_strike", &"fixture_volley"]),
		unit(&"fixture_shield", 16, 2, 2, 25.0, 2, [&"fixture_strike", &"fixture_bash"]),
		unit(&"fixture_herald", 14, 2, 1, 25.0, 3, [&"fixture_strike", &"fixture_rally", &"fixture_hex"]),
		unit(&"fixture_adder", 12, 3, 1, 25.0, 3, [&"fixture_strike", &"fixture_venom"]),
	]

static func placement(unit_id: StringName, faction_id: StringName, cell: Vector2i) -> BattlePlacement:
	var entry := BattlePlacement.new()
	entry.unit_id = unit_id
	entry.faction_id = faction_id
	entry.cell = cell
	return entry

## A battle on an open grid of `size`, with `blocked` cells.
static func battle(size := Vector2i(8, 6), blocked: Array[Vector2i] = []) -> AtbBattle:
	return AtbBattle.new(BattleGrid.new(size, blocked), FactionData.PLAYER)

## Fills `unit`'s gauge and starts its turn, as `AtbBattle.advance()` does once
## its gauge fills.
static func give_turn(battle_to_play: AtbBattle, turn_unit: GridUnit) -> void:
	turn_unit.gauge = AtbBattle.GAUGE_FULL
	battle_to_play.call("_on_gauge_full", turn_unit)
