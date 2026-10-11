class_name MineRunState
extends Node

signal floor_changed(floor: int)
signal deepest_floor_changed(floor: int)

const CURRENT_FLOOR_KEY := &"mine:current_floor"
const DEEPEST_FLOOR_KEY := &"mine:deepest_floor"
const CHECKPOINT_STEP := 5
const MAX_FLOOR := 120

## The rocks and enemies of generated floors; the game assigns it.
var floor_table: MineFloorTable

func get_current_floor() -> int:
	return clampi(_safe_int(WorldState.get_value(CURRENT_FLOOR_KEY, 1), 1), 1, MAX_FLOOR)

func get_deepest_floor() -> int:
	return clampi(_safe_int(WorldState.get_value(DEEPEST_FLOOR_KEY, 1), 1), 1, MAX_FLOOR)

func enter_from_surface() -> void:
	set_floor(1)

func set_floor(floor: int) -> int:
	var next_floor := clampi(floor, 1, MAX_FLOOR)
	var previous := get_current_floor()
	WorldState.set_value(CURRENT_FLOOR_KEY, next_floor)
	if next_floor > get_deepest_floor():
		WorldState.set_value(DEEPEST_FLOOR_KEY, next_floor)
		deepest_floor_changed.emit(next_floor)
	if previous != next_floor:
		floor_changed.emit(next_floor)
	return next_floor

func descend() -> int:
	return set_floor(get_current_floor() + 1)

func can_use_elevator_floor(floor: int) -> bool:
	if floor == 1:
		return true
	return floor > 0 and floor <= get_deepest_floor() and floor % CHECKPOINT_STEP == 0

func get_elevator_floors() -> PackedInt32Array:
	var result := PackedInt32Array([1])
	var floor := CHECKPOINT_STEP
	while floor <= get_deepest_floor():
		result.append(floor)
		floor += CHECKPOINT_STEP
	return result

func is_checkpoint_floor(floor: int) -> bool:
	return floor >= CHECKPOINT_STEP and floor % CHECKPOINT_STEP == 0

func get_deepest_checkpoint() -> int:
	var deepest := get_deepest_floor()
	return int(deepest / CHECKPOINT_STEP) * CHECKPOINT_STEP if deepest >= CHECKPOINT_STEP else 1

func get_floor_seed(floor: int) -> int:
	return absi(hash("mine-floor:%d:%d" % [WeatherState.world_seed, clampi(floor, 1, MAX_FLOOR)])) + 1

func generate_floor_layout(floor: int) -> Dictionary:
	var resolved := clampi(floor, 2, MAX_FLOOR)
	var rng := RandomNumberGenerator.new()
	rng.seed = get_floor_seed(resolved)
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

func _pick_position(rng: RandomNumberGenerator, occupied: Array[Vector2]) -> Vector2:
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

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
