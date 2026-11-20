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
## same floor of the same world always has the same rocks and enemies. A floor
## that a guardian tier guards (`MineFloorTable.get_guardian_ids()`) holds its
## guardians, furthest from the way in, and half the ordinary enemies; the
## layout lists them first among its enemies, marked `"guardian": true`. Each
## ordinary enemy is of the floor's leading kind (`MineFloorTable.get_enemy_id()`)
## or of a mixed tier that spans the floor (`EnemyTier.share`), and may come in
## an elite form (`MineFloorTable.elite_odds`), its id under `"elite"` (empty:
## none), each rolled from a stream of its own. Its `"hazards"` are where the
## table's hazards stand (`MineFloorTable.hazards`), clear of the rocks, the
## enemies and the ways in and down, each with its `"phase"`, the share of
## its cycle it starts at, from a stream of their own too. Its `"chests"`
## hold the floor's chest when it has one (`MineFloorTable.chests`), clear of
## all of those, with its `"persistent_id"`, so what it holds is found once in
## a world, and `"hoard"` on a guarded floor.
## `deepest_floor_changed` fires when the player goes deeper than ever before,
## their first entry to floor 1 included, which quests follow.

signal floor_changed(floor: int)
signal deepest_floor_changed(floor: int)

const TRACK_KEY := &"mine"
const CHECKPOINT_STEP := 5
const MAX_FLOOR := 120
# Where a floor's rocks and enemies stand, how far apart, and how far from its
# way in and its way down.
const FLOOR_AREA := Rect2(-205, -132, 450, 264)
const SPACING := 42.0
const ENTRANCE := Vector2(-305, 0)
const ENTRANCE_CLEARANCE := 95.0
const EXIT := Vector2(300, 0)
const EXIT_CLEARANCE := 70.0

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

## The names, in the player's language, of the guardians that stand on
## `floor` now: those its table names (`MineFloorTable.get_guardian_ids()`)
## that do not lie defeated (`HostileCreature.is_down()`).
func get_standing_guardian_names(floor: int) -> PackedStringArray:
	var names := PackedStringArray()
	if floor_table == null or floor < 2:
		return names
	var resolved := mini(floor, MAX_FLOOR)
	var ids := floor_table.get_guardian_ids(resolved)
	for index: int in ids.size():
		var data := EnemyData.find(ids[index])
		if data != null and not HostileCreature.is_down(guardian_persistent_id(resolved, index), data):
			names.append(tr(data.display_name))
	return names

## The id the `index`th guardian of `floor` is saved under.
static func guardian_persistent_id(floor: int, index: int) -> StringName:
	return StringName("mine_f%03d_guardian_%02d" % [floor, index + 1])

func generate_floor_layout(floor: int) -> Dictionary:
	var resolved := clampi(floor, 2, MAX_FLOOR)
	var rng := track.stream(resolved)
	var rocks: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
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
	if floor_table == null:
		rock_count = 0
	var enemy_kind := floor_table.get_enemy_id(resolved) if floor_table != null else StringName()
	if enemy_kind.is_empty():
		enemy_count = 0
	var guardian_kinds: Array[StringName] = []
	if floor_table != null:
		guardian_kinds = floor_table.get_guardian_ids(resolved)
	if not guardian_kinds.is_empty():
		enemy_count = int(enemy_count / 2)
	var scattered := rng.scatter(FLOOR_AREA, rock_count + enemy_count + guardian_kinds.size(), SPACING, PackedVector2Array(), Vector2(8, 8), _is_clear_of_doorways, 64)
	var positions: Array[Vector2] = []
	positions.assign(Array(scattered))
	if not guardian_kinds.is_empty():
		# Guardians wait deepest in the floor, the furthest points from the way in.
		positions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(ENTRANCE) > b.distance_squared_to(ENTRANCE))
	for index in range(guardian_kinds.size()):
		enemies.append({
			"kind": String(guardian_kinds[index]),
			"position": positions[index],
			"persistent_id": String(guardian_persistent_id(resolved, index)),
			"guardian": true,
			"elite": "",
		})
	var first := guardian_kinds.size()
	for index in range(rock_count):
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
			"position": positions[first + index],
			"persistent_id": "mine_f%03d_rock_%02d" % [resolved, index + 1],
		})
	# Streams of their own, so the mixed kinds and the elites leave the
	# floor's layout as it was.
	var mixed_rolls := track.stream(resolved, "mixed")
	var elite_rolls := track.stream(resolved, "elites")
	for index in range(enemy_count):
		var mixed := EnemyTier.pick_mixed(floor_table.enemy_tiers, resolved, mixed_rolls)
		var elite: EliteData = floor_table.elite_odds.roll(elite_rolls, resolved) if floor_table.elite_odds != null else null
		enemies.append({
			"kind": String(mixed if not mixed.is_empty() else enemy_kind),
			"position": positions[first + rock_count + index],
			"persistent_id": "mine_f%03d_enemy_%02d" % [resolved, index + 1],
			"elite": String(elite.id) if elite != null else "",
		})
	var hazards: Array[Dictionary] = []
	if floor_table != null and floor_table.hazards != null:
		var hazard_rolls := track.stream(resolved, "hazards")
		for place: Vector2 in floor_table.hazards.spread(hazard_rolls, resolved, FLOOR_AREA, scattered, _is_clear_of_doorways):
			hazards.append({"position": place, "phase": hazard_rolls.randf()})
	var chests: Array[Dictionary] = []
	if floor_table != null and floor_table.chests != null:
		var chest_rolls := track.stream(resolved, "chest")
		var guarded := not guardian_kinds.is_empty()
		if floor_table.chests.holds_chest(chest_rolls, resolved, guarded):
			var taken := scattered.duplicate()
			for hazard: Dictionary in hazards:
				taken.append(hazard["position"])
			chests.append({
				"position": chest_rolls.scatter(FLOOR_AREA, 1, SPACING, taken, Vector2(8, 8), _is_clear_of_doorways, 64)[0],
				"persistent_id": "mine_f%03d_chest" % resolved,
				"hoard": guarded and floor_table.chests.hoard != null,
			})
	return {"floor": resolved, "rocks": rocks, "enemies": enemies, "hazards": hazards, "chests": chests}

# Whether `point` keeps clear of the floor's way in and its way down.
static func _is_clear_of_doorways(point: Vector2) -> bool:
	return point.distance_to(ENTRANCE) >= ENTRANCE_CLEARANCE and point.distance_to(EXIT) >= EXIT_CLEARANCE
