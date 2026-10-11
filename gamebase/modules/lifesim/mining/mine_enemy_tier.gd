class_name MineEnemyTier
extends Resource

## The enemy a MineFloorTable spawns from `minimum_floor` until a deeper tier
## takes over.

@export var enemy_id: StringName
@export_range(1, 120, 1) var minimum_floor := 1
