class_name MineFloorController
extends Node2D

const MINING_SCENE := preload("res://game/core/mining/mining_node.tscn")
const ENEMY_SCENE := preload("res://game/core/combat/hostile_creature.tscn")
const STONE_DATA := preload("res://game/data/mining/stone_rock.tres")
const COPPER_DATA := preload("res://game/data/mining/copper_rock.tres")
const IRON_DATA := preload("res://game/data/mining/iron_rock.tres")
const GOLD_DATA := preload("res://game/data/mining/gold_rock.tres")
const IRIDIUM_DATA := preload("res://game/data/mining/iridium_rock.tres")
const SLIME_DATA := preload("res://game/data/enemies/green_slime.tres")
const CAVE_SLIME_DATA := preload("res://game/data/enemies/cave_slime.tres")
const BLUE_SLIME_DATA := preload("res://game/data/enemies/blue_slime.tres")
const RED_SLIME_DATA := preload("res://game/data/enemies/red_slime.tres")
const SHADOW_SLIME_DATA := preload("res://game/data/enemies/shadow_slime.tres")
const VOID_SLIME_DATA := preload("res://game/data/enemies/void_slime.tres")
const ANCIENT_SLIME_DATA := preload("res://game/data/enemies/ancient_slime.tres")
const FLOOR_ONE_NODE_NAMES := [&"StoneRockA", &"StoneRockB", &"CopperRock", &"GreenSlime"]

@onready var mine_label: Label = $MineLabel
@onready var ladder: MineLadder = $DeepLadder
@onready var elevator: MineElevator = $MineElevator

var current_floor := 1
var _generated_rocks: Array[MiningNode] = []
var _generated_enemies: Array[HostileCreature] = []

func _enter_tree() -> void:
	# Entering from Riverside always means a fresh surface entrance. Internal
	# ladder/elevator reloads use floor_entry and preserve MineState.current_floor.
	if WorldTravel.get_pending_spawn_id() == &"from_riverside":
		MineState.enter_from_surface()

func _ready() -> void:
	current_floor = MineState.set_floor(MineState.get_current_floor())
	GameEvents.resource_mined.connect(_on_floor_progress_event)
	GameEvents.enemy_defeated.connect(_on_floor_progress_event)
	WorldClock.day_changed.connect(_on_day_changed)
	_refresh_label()
	if current_floor > 1:
		for node_name: StringName in FLOOR_ONE_NODE_NAMES:
			var node := get_node_or_null(NodePath(String(node_name)))
			if node != null:
				node.queue_free()
		_spawn_dynamic_floor.call_deferred(current_floor)
	else:
		_connect_floor_one_nodes()
		_refresh_ladder.call_deferred()

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
		var rock := MINING_SCENE.instantiate() as MiningNode
		rock_index += 1
		rock.name = "GeneratedRock%02d" % rock_index
		match String(entry.get("kind", "stone")):
			"iridium": rock.data = IRIDIUM_DATA
			"gold": rock.data = GOLD_DATA
			"iron": rock.data = IRON_DATA
			"copper": rock.data = COPPER_DATA
			_: rock.data = STONE_DATA
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
		var enemy := ENEMY_SCENE.instantiate() as HostileCreature
		enemy_index += 1
		enemy.name = "GeneratedEnemy%02d" % enemy_index
		match String(entry.get("kind", "green_slime")):
			"ancient_slime": enemy.data = ANCIENT_SLIME_DATA
			"void_slime": enemy.data = VOID_SLIME_DATA
			"shadow_slime": enemy.data = SHADOW_SLIME_DATA
			"red_slime": enemy.data = RED_SLIME_DATA
			"blue_slime": enemy.data = BLUE_SLIME_DATA
			"cave_slime": enemy.data = CAVE_SLIME_DATA
			_: enemy.data = SLIME_DATA
		enemy.persistent_id = StringName(String(entry.get("persistent_id", "")))
		add_child(enemy)
		enemy.position = entry.get("position", Vector2.ZERO)
		_generated_enemies.append(enemy)
	_refresh_ladder()

func _connect_floor_one_nodes() -> void:
	for rock_name: StringName in [&"StoneRockA", &"StoneRockB", &"CopperRock"]:
		var rock := get_node_or_null(NodePath(String(rock_name))) as MiningNode
		if rock != null:
			rock.depleted.connect(_on_node_state_changed)
			rock.respawned.connect(_on_node_state_changed)

func _get_floor_rocks() -> Array[MiningNode]:
	if current_floor > 1:
		return _generated_rocks
	var result: Array[MiningNode] = []
	for node_name: StringName in [&"StoneRockA", &"StoneRockB", &"CopperRock"]:
		var rock := get_node_or_null(NodePath(String(node_name))) as MiningNode
		if rock != null:
			result.append(rock)
	return result

func _get_floor_enemies() -> Array[HostileCreature]:
	if current_floor > 1:
		return _generated_enemies
	var result: Array[HostileCreature] = []
	var enemy := get_node_or_null("GreenSlime") as HostileCreature
	if enemy != null:
		result.append(enemy)
	return result

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

func _refresh_label() -> void:
	if mine_label != null:
		mine_label.text = "Old Mine · Floor %d · Deepest %d" % [current_floor, MineState.get_deepest_floor()]
