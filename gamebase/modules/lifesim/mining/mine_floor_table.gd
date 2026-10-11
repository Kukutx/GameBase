class_name MineFloorTable
extends Resource

## What the mine generates on the floors below the first: the game provides
## one (game_setup.gd assigns it to MineState.floor_table). Rocks and enemies
## are named by content id and resolved through ContentDB.

## The rock placed when no ore tier is rolled.
@export var default_rock_id: StringName
## Ore tiers, rarest first; the first unlocked tier is guaranteed on each floor.
@export var rock_tiers: Array[MineRockTier] = []
@export var enemy_tiers: Array[MineEnemyTier] = []

## The enemy id for `floor`: the tier with the deepest minimum floor reached.
func get_enemy_id(floor: int) -> StringName:
	var result := StringName()
	var best := 0
	for tier: MineEnemyTier in enemy_tiers:
		if tier != null and tier.minimum_floor <= floor and tier.minimum_floor > best:
			best = tier.minimum_floor
			result = tier.enemy_id
	return result

## Every id that ContentDB does not know, as readable problems.
func validate(registry: Node) -> PackedStringArray:
	var problems := PackedStringArray()
	if registry.call("get_mining_node", default_rock_id) == null:
		problems.append("mine floor table default rock '%s' is not a mining node" % default_rock_id)
	for tier: MineRockTier in rock_tiers:
		if tier == null or registry.call("get_mining_node", tier.rock_id) == null:
			problems.append("mine floor table rock tier '%s' is not a mining node" % (tier.rock_id if tier != null else &""))
	for tier: MineEnemyTier in enemy_tiers:
		if tier == null or registry.call("get_enemy", tier.enemy_id) == null:
			problems.append("mine floor table enemy tier '%s' is not an enemy" % (tier.enemy_id if tier != null else &""))
	return problems
