class_name MineRockTier
extends Resource

## One ore tier of a MineFloorTable. The tier unlocks on its rock's
## `minimum_mine_floor`, where it is guaranteed once; deeper, each generated
## rock rolls this chance:
##     min(base_chance + chance_per_floor * (floor - growth_start_floor), max_chance)

@export var rock_id: StringName
@export_range(0.0, 1.0, 0.001) var base_chance := 0.1
@export_range(0.0, 0.1, 0.0001) var chance_per_floor := 0.0
@export_range(0.0, 1.0, 0.001) var max_chance := 0.25
## The floor the chance starts growing from; -1 means the rock's unlock floor.
@export var growth_start_floor := -1

func get_chance(floor: int, unlock_floor: int) -> float:
	if floor < unlock_floor:
		return 0.0
	var start := unlock_floor if growth_start_floor < 0 else growth_start_floor
	return minf(base_chance + float(floor - start) * chance_per_floor, max_chance)
