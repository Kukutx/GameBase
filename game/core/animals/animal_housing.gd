class_name AnimalHousing
extends Node2D

@export var housing_id: StringName
@export var location_id: StringName
@export var housing_type: StringName = &"coop"
@export_range(1, 32, 1) var capacity := 4
@export var spawn_positions: Array[Vector2] = []
@export var animal_scene: PackedScene = preload("res://game/core/animals/farm_animal.tscn")

var _spawned: Dictionary = {}

func _ready() -> void:
	AnimalState.register_housing(housing_id, location_id, housing_type, capacity)
	AnimalState.ownership_changed.connect(_on_ownership_changed)
	_refresh_animals.call_deferred()

func _exit_tree() -> void:
	AnimalState.unregister_housing(housing_id)

func get_spawned_animals() -> Array[FarmAnimal]:
	var result: Array[FarmAnimal] = []
	for value: Variant in _spawned.values():
		if is_instance_valid(value):
			result.append(value as FarmAnimal)
	return result

func _on_ownership_changed(changed_location_id: StringName) -> void:
	if changed_location_id == location_id:
		_refresh_animals.call_deferred()

func _refresh_animals() -> void:
	var desired: Dictionary = {}
	for record: Dictionary in AnimalState.get_owned(location_id, housing_id):
		var instance_id := StringName(String(record.get("instance_id", "")))
		if instance_id == &"":
			continue
		desired[String(instance_id)] = true
		if _spawned.has(String(instance_id)) and is_instance_valid(_spawned[String(instance_id)]):
			var existing := _spawned[String(instance_id)] as FarmAnimal
			if existing != null:
				existing.set_custom_name(String(record.get("custom_name", "")))
			continue
		_spawn_animal(record)
	for key: String in _spawned.keys():
		if desired.has(key):
			continue
		var animal := _spawned[key] as FarmAnimal
		if is_instance_valid(animal):
			animal.queue_free()
		_spawned.erase(key)

func _spawn_animal(record: Dictionary) -> void:
	if animal_scene == null or get_parent() == null:
		return
	var animal_id := StringName(String(record.get("animal_id", "")))
	var data := ContentDB.get_farm_animal(animal_id)
	if data == null:
		return
	var animal := animal_scene.instantiate() as FarmAnimal
	if animal == null:
		return
	var instance_id := StringName(String(record.get("instance_id", "")))
	animal.data = data
	animal.persistent_id = instance_id
	animal.custom_name = String(record.get("custom_name", ""))
	animal.name = String(record.get("node_name", data.display_name.validate_node_name()))
	var slot_index := maxi(int(record.get("slot_index", 0)), 0)
	get_parent().add_child(animal)
	animal.global_position = global_position + _position_for_slot(slot_index)
	_spawned[String(instance_id)] = animal

func _position_for_slot(slot_index: int) -> Vector2:
	if slot_index >= 0 and slot_index < spawn_positions.size():
		return spawn_positions[slot_index]
	var effective_capacity := maxi(AnimalState.get_housing_capacity(housing_id), capacity)
	var columns := maxi(int(ceil(sqrt(float(effective_capacity)))), 1)
	var x := slot_index % columns
	var y := slot_index / columns
	return Vector2((x - (columns - 1) * 0.5) * 30.0, y * 28.0)
