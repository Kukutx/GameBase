class_name MineFloorTable
extends Resource

## What the mine generates on the floors below the first: the game provides
## one (its `GameSetup` module assigns it to `MineState.floor_table`). Rocks and
## enemies are named by content id.

## The rock placed when no ore tier is rolled.
@export var default_rock_id: StringName
## Ore tiers, rarest first; the first unlocked tier is guaranteed on each floor.
@export var rock_tiers: Array[MineRockTier] = []
@export var enemy_tiers: Array[EnemyTier] = []
## How often the ordinary enemies of a floor come in an elite form
## (`EliteData`); none without.
@export var elite_odds: EliteOdds
## The hazards of the ground (`Hazard`) spread over the floors, the deeper the
## more; none without.
@export var hazards: HazardSpread

## The enemy id for `floor`: the tier with the deepest minimum floor reached.
func get_enemy_id(floor: int) -> StringName:
	return EnemyTier.deepest(enemy_tiers, floor)

## The enemy ids of the guardian tiers (`EnemyTier.guardian_every`) that guard
## `floor`; empty on an ordinary floor.
func get_guardian_ids(floor: int) -> Array[StringName]:
	return EnemyTier.guardians(enemy_tiers, floor)

## Every id that `registry` does not know, as readable problems.
func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not registry.has_entry(MiningNodeData.KIND, default_rock_id):
		problems.append("mine floor table default rock '%s' is not a mining node" % default_rock_id)
	for tier: MineRockTier in rock_tiers:
		if tier == null or not registry.has_entry(MiningNodeData.KIND, tier.rock_id):
			problems.append("mine floor table rock tier '%s' is not a mining node" % (tier.rock_id if tier != null else &""))
	for problem: String in EnemyTier.find_problems(enemy_tiers, registry):
		problems.append("mine floor table %s" % problem)
	if hazards != null:
		for problem: String in hazards.find_problems():
			problems.append("mine floor table %s" % problem)
	return problems
