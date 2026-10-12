extends RefCounted

## Fixture content for the tactics module's tests: a strike, a shot, a blast
## that reaches an area and a mend, and units that take them.
##
##     const TacticsFixture := preload("res://gamebase/modules/tactics/test/tactics_fixture.gd")

static func action(id: StringName, power: int, min_range := 1, max_range := 1, area := 0, heals := false) -> BattleActionData:
	var entry := BattleActionData.new()
	entry.id = id
	entry.display_name = String(id).capitalize()
	entry.power = power
	entry.min_range = min_range
	entry.max_range = max_range
	entry.area = area
	entry.effect = BattleActionData.Effect.HEAL if heals else BattleActionData.Effect.DAMAGE
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
## two or three cells away), a healer (mends one cell away or itself), a raider
## and a mage (blasts an area), whose actions do the power plus the attack less
## the defense.
static func entries() -> Array:
	return [
		action(&"fixture_strike", 3),
		action(&"fixture_shot", 2, 2, 3),
		action(&"fixture_blast", 2, 1, 3, 1),
		action(&"fixture_mend", 5, 0, 1, 0, true),
		unit(&"fixture_knight", 20, 4, 2, 50.0, 3, [&"fixture_strike"]),
		unit(&"fixture_archer", 12, 3, 0, 25.0, 3, [&"fixture_shot"]),
		unit(&"fixture_healer", 10, 0, 0, 25.0, 3, [&"fixture_mend", &"fixture_strike"]),
		unit(&"fixture_raider", 12, 3, 1, 25.0, 3, [&"fixture_strike"]),
		unit(&"fixture_mage", 8, 2, 0, 20.0, 2, [&"fixture_blast"]),
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
