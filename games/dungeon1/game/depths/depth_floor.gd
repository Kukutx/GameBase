class_name DepthFloor
extends Node2D

## The root of the depths' scene: one floor of a run. It lays out the enemies
## of the run's depth (`DepthRun`) from `enemy_tiers` with the run's random
## stream, so a floor comes back the same only within the same run. Once every
## enemy is defeated the way on opens: the stairs down to the next depth, or
## the rope back up to camp with what the player found.

const ENEMY_SCENE := preload("res://gamebase/modules/combat/combat/hostile_creature.tscn")

## The enemies floors spawn, each from its minimum depth on; deeper tiers come
## up more often.
@export var enemy_tiers: Array[EnemyTier] = []
## Where enemies may stand, in the scene's coordinates.
@export var arena := Rect2(-200, -110, 400, 220)
## The spawn point the player arrives at; enemies keep `arrival_clearance` away.
@export var arrival_spawn_id: StringName = &"arrival"
@export var arrival_clearance := 90.0
## Where the rope leads.
@export var camp_location_id: StringName
@export var camp_spawn_id: StringName

@onready var depth_label: Label = $DepthLabel
@onready var stairs: Node2D = $Stairs
@onready var rope: Node2D = $Rope

var _enemies: Array[HostileCreature] = []

func _ready() -> void:
	(stairs.get_node("Interactable") as Interactable).interacted.connect(_descend)
	(rope.get_node("Interactable") as Interactable).interacted.connect(_climb)
	CombatEvents.enemy_defeated.connect(_on_enemy_defeated)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_spawn_enemies()
	_refresh()

## How many enemies a floor at `depth` spawns.
static func get_enemy_count(depth: int) -> int:
	return clampi(2 + depth / 2, 2, 8)

func get_enemies() -> Array[HostileCreature]:
	return _enemies.duplicate()

## Whether every enemy of the floor is defeated.
func is_cleared() -> bool:
	for enemy: HostileCreature in _enemies:
		if is_instance_valid(enemy) and not enemy.is_defeated:
			return false
	return true

func _spawn_enemies() -> void:
	var depth := DepthRun.get_depth()
	var kinds := EnemyTier.reached(enemy_tiers, depth)
	if kinds.is_empty():
		return
	var rng := DepthRun.floor_stream()
	var arrival := _spawn_position(arrival_spawn_id)
	var taken: Array[Vector2] = []
	for index: int in get_enemy_count(depth):
		# The larger of two rolls, so the deeper of the reached tiers come up more.
		var kind := kinds[maxi(rng.randi_range(0, kinds.size() - 1), rng.randi_range(0, kinds.size() - 1))]
		var enemy := ENEMY_SCENE.instantiate() as HostileCreature
		enemy.name = "Enemy%02d" % (index + 1)
		enemy.data = EnemyData.find(kind)
		enemy.position = _pick_position(rng, arrival, taken)
		taken.append(enemy.position)
		add_child(enemy)
		_enemies.append(enemy)

func _pick_position(rng: GameRandomStream, arrival: Vector2, taken: Array[Vector2]) -> Vector2:
	var candidate := arena.get_center()
	for _attempt: int in 32:
		candidate = Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y)).snapped(Vector2(8, 8))
		if candidate.distance_to(arrival) < arrival_clearance:
			continue
		if taken.all(func(other: Vector2) -> bool: return candidate.distance_to(other) >= 28.0):
			return candidate
	return candidate

func _spawn_position(spawn_id: StringName) -> Vector2:
	for child: Node in get_children():
		if child is WorldSpawnPoint and (child as WorldSpawnPoint).spawn_id == spawn_id:
			return (child as Node2D).position
	return Vector2.ZERO

func _descend(_actor: Node) -> void:
	var location := WorldLocationData.find_for_scene(scene_file_path)
	if location == null or not is_cleared() or not WorldTravel.can_travel_to(location.id, arrival_spawn_id):
		return
	DepthRun.descend()
	WorldTravel.travel_to(location.id, arrival_spawn_id)

func _climb(_actor: Node) -> void:
	if is_cleared():
		WorldTravel.travel_to(camp_location_id, camp_spawn_id)

func _on_enemy_defeated(_enemy_id: StringName, _combat_xp: int) -> void:
	_refresh.call_deferred()

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _refresh() -> void:
	var cleared := is_cleared()
	for way: Node2D in [stairs, rope]:
		way.visible = cleared
		(way.get_node("Interactable") as Interactable).enabled = cleared
	depth_label.text = tr("Depth %d · Deepest %d") % [DepthRun.get_depth(), DepthRun.get_deepest()]
	if cleared and not _enemies.is_empty():
		depth_label.text += "\n" + tr("The way on is open")

func find_scene_problems(registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	for problem: String in EnemyTier.find_problems(enemy_tiers, registry):
		problems.append("depth floor %s" % problem)
	if EnemyTier.reached(enemy_tiers, 1).is_empty():
		problems.append("depth floor has no enemy tier from depth 1")
	if location != null and not registry.has_location_spawn(location.id, arrival_spawn_id):
		problems.append("depth floor arrives at spawn '%s', which its scene does not have" % arrival_spawn_id)
	if not registry.has_location_spawn(camp_location_id, camp_spawn_id):
		problems.append("depth floor's rope leads to spawn '%s' of '%s', which does not exist" % [camp_spawn_id, camp_location_id])
	return problems
