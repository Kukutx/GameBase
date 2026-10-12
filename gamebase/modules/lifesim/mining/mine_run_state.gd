class_name MineRunState
extends Node

## The mine: the floor the player is on and the deepest floor they reached, from
## 1 to `MAX_FLOOR`, kept by a `DepthTrack` (`mine:depth`, `mine:deepest` in
## `WorldState`), so they are saved with the world and a new game starts on
## floor 1. The first floor counts as reached from the start. It also lays out
## each generated floor's rocks and enemies from the game's `floor_table`
## (`MineFloorTable`), and gives the elevator its stops: floor 1 and every
## `CHECKPOINT_STEP`th floor down to the deepest.
##
## A floor's layout comes from the world's seed (`DepthTrack.stream()`), so the
## same floor of the same world always has the same rocks and enemies.
## `deepest_floor_changed` fires when the player goes deeper than ever before,
## their first entry to floor 1 included, which quests follow.

signal floor_changed(floor: int)
signal deepest_floor_changed(floor: int)

const TRACK_KEY := &"mine"
const CHECKPOINT_STEP := 5
const MAX_FLOOR := 120

## The rocks and enemies of generated floors; the game assigns it.
var floor_table: MineFloorTable
## The mine's floors.
var track := DepthTrack.new(TRACK_KEY, MAX_FLOOR, CHECKPOINT_STEP)

func _ready() -> void:
	track.depth_changed.connect(floor_changed.emit)
	track.deepest_changed.connect(deepest_floor_changed.emit)

func get_current_floor() -> int:
	return track.get_depth()

func get_deepest_floor() -> int:
	return maxi(track.get_deepest(), 1)

func enter_from_surface() -> void:
	set_floor(1)

func set_floor(floor: int) -> int:
	return track.set_depth(floor)

func descend() -> int:
	return track.descend()

func can_use_elevator_floor(floor: int) -> bool:
	return track.can_return_to(floor)

func get_elevator_floors() -> PackedInt32Array:
	return track.get_checkpoints()

func is_checkpoint_floor(floor: int) -> bool:
	return track.is_checkpoint(floor)

func get_deepest_checkpoint() -> int:
	return track.get_deepest_checkpoint()

func generate_floor_layout(floor: int) -> Dictionary:
	var resolved := clampi(floor, 2, MAX_FLOOR)
	var rng := track.stream(resolved)
	var rocks: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var occupied: Array[Vector2] = []
	var rock_count := clampi(3 + int(resolved / 2), 4, 10)
	var enemy_count := clampi(1 + int(resolved / 3), 1, 4)
	var tiers: Array[Dictionary] = []
	if floor_table != null:
		for tier: MineRockTier in floor_table.rock_tiers:
			var node: MiningNodeData = MiningNodeData.find(tier.rock_id) if tier != null else null
			if node != null:
				var unlocked := resolved >= node.minimum_mine_floor
				tiers.append({"id": tier.rock_id, "unlocked": unlocked, "chance": tier.get_chance(resolved, node.minimum_mine_floor)})
	var default_rock := floor_table.default_rock_id if floor_table != null else StringName()
	var guaranteed := StringName()
	for tier: Dictionary in tiers:
		if bool(tier["unlocked"]):
			guaranteed = tier["id"]
			break
	for index in range(rock_count if floor_table != null else 0):
		var position := _pick_position(rng, occupied)
		occupied.append(position)
		var roll := rng.randf()
		var kind := default_rock
		# A new ore tier is guaranteed on its unlock floor so progression never
		# depends on a lucky procedural roll.
		if index == 0 and not guaranteed.is_empty():
			kind = guaranteed
		else:
			var cumulative := 0.0
			for tier: Dictionary in tiers:
				var chance := float(tier["chance"])
				if chance <= 0.0:
					continue
				cumulative += chance
				if roll <= cumulative:
					kind = tier["id"]
					break
		rocks.append({
			"kind": String(kind),
			"position": position,
			"persistent_id": "mine_f%03d_rock_%02d" % [resolved, index + 1],
		})
	var enemy_kind := floor_table.get_enemy_id(resolved) if floor_table != null else StringName()
	for index in range(enemy_count if not enemy_kind.is_empty() else 0):
		var position := _pick_position(rng, occupied)
		occupied.append(position)
		enemies.append({
			"kind": String(enemy_kind),
			"position": position,
			"persistent_id": "mine_f%03d_enemy_%02d" % [resolved, index + 1],
		})
	return {"floor": resolved, "rocks": rocks, "enemies": enemies}

func _pick_position(rng: GameRandomStream, occupied: Array[Vector2]) -> Vector2:
	for _attempt in range(64):
		var candidate := Vector2(rng.randf_range(-205.0, 245.0), rng.randf_range(-132.0, 132.0)).snapped(Vector2(8, 8))
		if candidate.distance_to(Vector2(-305, 0)) < 95.0 or candidate.distance_to(Vector2(300, 0)) < 70.0:
			continue
		var clear := true
		for point: Vector2 in occupied:
			if candidate.distance_to(point) < 42.0:
				clear = false
				break
		if clear:
			return candidate
	return Vector2(rng.randf_range(-180.0, 220.0), rng.randf_range(-120.0, 120.0)).snapped(Vector2(8, 8))
