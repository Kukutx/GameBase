class_name MineRunState
extends Node

signal floor_changed(floor: int)
signal deepest_floor_changed(floor: int)

const CURRENT_FLOOR_KEY := &"mine:current_floor"
const DEEPEST_FLOOR_KEY := &"mine:deepest_floor"
const CHECKPOINT_STEP := 5
const MAX_FLOOR := 120
const COPPER_NODE_DATA := preload("res://game/data/mining/copper_rock.tres")
const IRON_NODE_DATA := preload("res://game/data/mining/iron_rock.tres")
const GOLD_NODE_DATA := preload("res://game/data/mining/gold_rock.tres")
const IRIDIUM_NODE_DATA := preload("res://game/data/mining/iridium_rock.tres")

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
	var copper_floor: int = COPPER_NODE_DATA.minimum_mine_floor
	var iron_floor: int = IRON_NODE_DATA.minimum_mine_floor
	var gold_floor: int = GOLD_NODE_DATA.minimum_mine_floor
	var iridium_floor: int = IRIDIUM_NODE_DATA.minimum_mine_floor
	var copper_chance := 0.0 if resolved < copper_floor else minf(0.18 + float(resolved) * 0.006, 0.25)
	var iron_chance := 0.0 if resolved < iron_floor else minf(0.14 + float(resolved - iron_floor) * 0.004, 0.26)
	var gold_chance := 0.0 if resolved < gold_floor else minf(0.10 + float(resolved - gold_floor) * 0.0025, 0.22)
	var iridium_chance := 0.0 if resolved < iridium_floor else minf(0.08 + float(resolved - iridium_floor) * 0.0015, 0.16)
	for index in range(rock_count):
		var position := _pick_position(rng, occupied)
		occupied.append(position)
		var roll := rng.randf()
		var kind := &"stone"
		# A new ore tier is guaranteed on its unlock floor so progression never
		# depends on a lucky procedural roll.
		if resolved >= iridium_floor and index == 0:
			kind = &"iridium"
		elif resolved >= gold_floor and index == 0:
			kind = &"gold"
		elif resolved >= iron_floor and index == 0:
			kind = &"iron"
		elif resolved >= copper_floor and index == 0:
			kind = &"copper"
		elif iridium_chance > 0.0 and roll <= iridium_chance:
			kind = &"iridium"
		elif gold_chance > 0.0 and roll <= iridium_chance + gold_chance:
			kind = &"gold"
		elif iron_chance > 0.0 and roll <= iridium_chance + gold_chance + iron_chance:
			kind = &"iron"
		elif roll <= iridium_chance + gold_chance + iron_chance + copper_chance:
			kind = &"copper"
		rocks.append({
			"kind": String(kind),
			"position": position,
			"persistent_id": "mine_f%03d_rock_%02d" % [resolved, index + 1],
		})
	var enemy_kind := "green_slime"
	if resolved >= 120:
		enemy_kind = "ancient_slime"
	elif resolved >= 90:
		enemy_kind = "void_slime"
	elif resolved >= 60:
		enemy_kind = "shadow_slime"
	elif resolved >= 40:
		enemy_kind = "red_slime"
	elif resolved >= 20:
		enemy_kind = "blue_slime"
	elif resolved >= 10:
		enemy_kind = "cave_slime"
	for index in range(enemy_count):
		var position := _pick_position(rng, occupied)
		occupied.append(position)
		enemies.append({
			"kind": enemy_kind,
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
