extends RefCounted

## Fixture content for the rts module's tests: a footman that fights up
## close, a bowman that shoots from afar, a raider and a brute.
##
##     const RtsFixture := preload("res://gamebase/modules/rts/test/rts_fixture.gd")

static func unit(id: StringName, health: int, damage: int, armor: int, attack_range: float, cooldown: float, speed: float, sight: float, radius := 5.0) -> RtsUnitData:
	var entry := RtsUnitData.new()
	entry.id = id
	entry.display_name = String(id).capitalize()
	entry.max_health = health
	entry.damage = damage
	entry.armor = armor
	entry.attack_range = attack_range
	entry.attack_cooldown = cooldown
	entry.move_speed = speed
	entry.sight_range = sight
	entry.radius = radius
	return entry

## The fixture units: a footman (30 health, 6 damage, 1 armor, a blow every
## second), a bowman (shoots 50 pixels away every second and a half), a
## raider (24 health, 5 damage) and a slow brute (60 health, 2 armor).
static func entries() -> Array:
	return [
		unit(&"fixture_footman", 30, 6, 1, 3.0, 1.0, 30.0, 60.0),
		unit(&"fixture_bowman", 20, 4, 0, 50.0, 1.5, 28.0, 70.0, 4.0),
		unit(&"fixture_raider", 24, 5, 0, 3.0, 1.0, 32.0, 60.0),
		unit(&"fixture_brute", 60, 12, 2, 4.0, 2.0, 20.0, 50.0, 7.0),
	]

static func placement(unit_id: StringName, faction_id: StringName, position: Vector2) -> RtsPlacement:
	var entry := RtsPlacement.new()
	entry.unit_id = unit_id
	entry.faction_id = faction_id
	entry.position = position
	return entry

## A battle on a field of `size` with `obstacles`, the player's faction
## `FactionData.PLAYER`; the units the player does not command stay put
## unless a test has them advance.
static func battle(size := Vector2(320.0, 160.0), obstacles: Array[Rect2] = []) -> RtsBattle:
	var made := RtsBattle.new(size, obstacles)
	made.computer_advances = false
	return made

## Places a unit of fixture kind `unit_id`.
static func add(battle_to_fill: RtsBattle, unit_id: StringName, faction: StringName, position: Vector2) -> RtsUnit:
	return battle_to_fill.add_unit(RtsUnitData.find(unit_id), faction, position)

## Lets the battle run a step at a time until `condition` holds or `seconds`
## of battle pass; whether it held.
static func run_until(battle_to_run: RtsBattle, condition: Callable, seconds: float) -> bool:
	var steps := ceili(seconds / RtsBattle.STEP)
	for _step in steps:
		if condition.call():
			return true
		battle_to_run.advance(RtsBattle.STEP)
	return bool(condition.call())
