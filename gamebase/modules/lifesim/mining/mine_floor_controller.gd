class_name MineFloorController
extends Node2D

## The root of a mine location's scene. Floor 1 is the scene as built: the
## MiningNode and HostileCreature children placed in it. Deeper floors replace
## them with rocks and enemies generated from `MineState.floor_table`. Every
## floor is the same location; its ladder and elevator reload it.

const MINING_SCENE := preload("res://gamebase/modules/lifesim/mining/mining_node.tscn")
const ENEMY_SCENE := preload("res://gamebase/modules/combat/combat/hostile_creature.tscn")

## Spawn points the mine is entered at from outside; arriving at one starts again at floor 1.
@export var entrance_spawn_ids: Array[StringName] = []
## Spawn point the ladder and the elevator bring the player to on another floor.
@export var floor_spawn_id: StringName

@onready var mine_label: Label = $MineLabel
@onready var ladder: MineLadder = $DeepLadder
@onready var elevator: MineElevator = $MineElevator

var current_floor := 1
var _placed_rocks: Array[MiningNode] = []
var _placed_enemies: Array[HostileCreature] = []
var _generated_rocks: Array[MiningNode] = []
var _generated_enemies: Array[HostileCreature] = []

func _enter_tree() -> void:
	# Ladder and elevator reloads arrive at floor_spawn_id and keep the floor.
	if entrance_spawn_ids.has(WorldTravel.get_pending_spawn_id()):
		MineState.enter_from_surface()

func _ready() -> void:
	current_floor = MineState.set_floor(MineState.get_current_floor())
	ladder.mine = self
	elevator.mine = self
	GameEvents.resource_mined.connect(_on_floor_progress_event)
	GameEvents.enemy_defeated.connect(_on_floor_progress_event)
	WorldClock.day_changed.connect(_on_day_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh_label()
	for child: Node in get_children():
		if child is MiningNode:
			_placed_rocks.append(child as MiningNode)
		elif child is HostileCreature:
			_placed_enemies.append(child as HostileCreature)
	if current_floor > 1:
		for rock: MiningNode in _placed_rocks:
			rock.queue_free()
		for enemy: HostileCreature in _placed_enemies:
			enemy.queue_free()
		_placed_rocks.clear()
		_placed_enemies.clear()
		_spawn_dynamic_floor.call_deferred(current_floor)
	else:
		for rock: MiningNode in _placed_rocks:
			rock.depleted.connect(_on_node_state_changed)
			rock.respawned.connect(_on_node_state_changed)
		_refresh_ladder.call_deferred()

## Brings the player to `floor` of this mine. Returns false when the travel
## could not start.
func travel_to_floor(floor: int) -> bool:
	var location := ContentDB.get_location_for_scene(scene_file_path)
	if location == null or floor_spawn_id == &"" or not WorldTravel.travel_to(location.id, floor_spawn_id):
		return false
	MineState.set_floor(floor)
	return true

func get_generated_rocks() -> Array[MiningNode]:
	return _generated_rocks.duplicate()

func get_generated_enemies() -> Array[HostileCreature]:
	return _generated_enemies.duplicate()

func is_floor_cleared() -> bool:
	var rocks := _get_floor_rocks()
	var enemies := _get_floor_enemies()
	if rocks.is_empty() and enemies.is_empty():
		return false
	for rock: MiningNode in rocks:
		if is_instance_valid(rock) and not rock.is_depleted:
			return false
	for enemy: HostileCreature in enemies:
		if is_instance_valid(enemy) and not enemy.is_defeated:
			return false
	return true

func _spawn_dynamic_floor(floor: int) -> void:
	_generated_rocks.clear()
	_generated_enemies.clear()
	var layout := MineState.generate_floor_layout(floor)
	var rock_index := 0
	for raw: Variant in layout.get("rocks", []):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var rock_data := MiningNodeData.find(StringName(String(entry.get("kind", ""))))
		if rock_data == null:
			continue
		var rock := MINING_SCENE.instantiate() as MiningNode
		rock_index += 1
		rock.name = "GeneratedRock%02d" % rock_index
		rock.data = rock_data
		rock.persistent_id = StringName(String(entry.get("persistent_id", "")))
		add_child(rock)
		rock.position = entry.get("position", Vector2.ZERO)
		rock.depleted.connect(_on_node_state_changed)
		rock.respawned.connect(_on_node_state_changed)
		_generated_rocks.append(rock)
	var enemy_index := 0
	for raw: Variant in layout.get("enemies", []):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var enemy_data := EnemyData.find(StringName(String(entry.get("kind", ""))))
		if enemy_data == null:
			continue
		var enemy := ENEMY_SCENE.instantiate() as HostileCreature
		enemy_index += 1
		enemy.name = "GeneratedEnemy%02d" % enemy_index
		enemy.data = enemy_data
		enemy.persistent_id = StringName(String(entry.get("persistent_id", "")))
		add_child(enemy)
		enemy.position = entry.get("position", Vector2.ZERO)
		_generated_enemies.append(enemy)
	_refresh_ladder()

func _get_floor_rocks() -> Array[MiningNode]:
	return _generated_rocks if current_floor > 1 else _placed_rocks

func _get_floor_enemies() -> Array[HostileCreature]:
	return _generated_enemies if current_floor > 1 else _placed_enemies

func _on_floor_progress_event(_a: Variant, _b: Variant = null, _c: Variant = null) -> void:
	_refresh_ladder.call_deferred()

func _on_node_state_changed(_node_id: StringName) -> void:
	_refresh_ladder.call_deferred()

func _on_day_changed(_day: int) -> void:
	_refresh_ladder.call_deferred()

func _refresh_ladder() -> void:
	if ladder != null:
		ladder.set_unlocked(is_floor_cleared() and current_floor < MineRunState.MAX_FLOOR)
	if elevator != null:
		elevator.refresh()

func _on_locale_changed(_locale: String) -> void:
	_refresh_label()
	_refresh_ladder()

func _refresh_label() -> void:
	if mine_label != null:
		var location := ContentDB.get_current_location(get_tree())
		var mine_name := tr(location.display_name) if location != null else ""
		mine_label.text = tr("%s · Floor %d · Deepest %d") % [mine_name, current_floor, MineState.get_deepest_floor()]

func find_scene_problems(registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	if location == null:
		return problems
	if entrance_spawn_ids.is_empty():
		problems.append("mine '%s' has no entrance spawn" % name)
	for spawn_id: StringName in entrance_spawn_ids + [floor_spawn_id]:
		if not registry.has_location_spawn(location.id, spawn_id):
			problems.append("mine '%s' names spawn '%s', which its scene does not have" % [name, spawn_id])
	return problems
