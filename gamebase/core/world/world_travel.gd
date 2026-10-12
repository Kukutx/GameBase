class_name WorldTravelService
extends Node

signal travel_started(scene_path: String, spawn_id: StringName)
signal travel_finished(scene_path: String, spawn_id: StringName)
signal travel_failed(scene_path: String, spawn_id: StringName, reason: String)
## Emitted when a travel that started ends: `arrived` after `travel_finished`,
## not after `travel_failed`.
signal travel_ended(arrived: bool)

var _pending_spawn_id: StringName = &""
var _pending_scene_path := ""
var _traveling := false
var _portal_grace_until_msec := 0
# Travels that started, and that ended, so far; `go_to` waits for its own.
var _travels_started := 0
var _travels_ended := 0
var _last_arrived := false

const ARRIVAL_PORTAL_GRACE_MSEC := 450

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	var transition := get_node_or_null("/root/Transition")
	if transition != null and transition.has_signal("scene_change_failed"):
		transition.connect("scene_change_failed", _on_scene_change_failed)

func can_enter_portal() -> bool:
	return not _traveling and Time.get_ticks_msec() >= _portal_grace_until_msec

func is_traveling() -> bool:
	return _traveling

func get_pending_spawn_id() -> StringName:
	return _pending_spawn_id

func can_travel_to(location_id: StringName, spawn_id: StringName = &"") -> bool:
	if _traveling:
		return false
	var location := WorldLocationData.find(location_id)
	if location == null or location.scene_path.is_empty() or not ResourceLoader.exists(location.scene_path):
		return false
	var target_spawn := spawn_id if spawn_id != &"" else location.default_spawn_id
	if target_spawn == &"" or not ContentRegistry.active.has_location_spawn(location_id, target_spawn):
		return false
	if DisplayServer.get_name() != "headless":
		var transition := get_node_or_null("/root/Transition")
		if transition == null or not transition.has_method("change_scene"):
			return false
	return true

func travel_to(location_id: StringName, spawn_id: StringName = &"") -> bool:
	if _traveling:
		return false
	var location := WorldLocationData.find(location_id)
	if location == null:
		travel_failed.emit("", spawn_id, "Unknown location: %s" % String(location_id))
		GameEvents.toastf("Unknown location: %s", [String(location_id)])
		return false
	var target_spawn := spawn_id if spawn_id != &"" else location.default_spawn_id
	if target_spawn == &"" or not ContentRegistry.active.has_location_spawn(location_id, target_spawn):
		travel_failed.emit(location.scene_path, target_spawn, "Unknown spawn '%s' for location '%s'" % [target_spawn, location_id])
		GameEvents.toast("Travel spawn is unavailable")
		return false
	return _travel_scene(location.scene_path, target_spawn)

## Travels as `travel_to` does and waits until this travel ends: true once
## the player stands in the location, false when it could not start or failed.
func go_to(location_id: StringName, spawn_id: StringName = &"") -> bool:
	if not travel_to(location_id, spawn_id):
		return false
	var travel := _travels_started
	while _travels_ended < travel:
		await travel_ended
	return _last_arrived

## Waits until the travel under way, if any, ends.
func wait_until_arrived() -> void:
	while _traveling:
		await travel_ended

func _travel_scene(scene_path: String, spawn_id: StringName = &"") -> bool:
	if _traveling:
		return false
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		travel_failed.emit(scene_path, spawn_id, "Travel scene is unavailable")
		return false
	# Without a screen there is no fade to load behind, so the scene loads now.
	var headless := DisplayServer.get_name() == "headless"
	var packed: PackedScene = null
	if headless:
		packed = ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			travel_failed.emit(scene_path, spawn_id, "Travel target is not a PackedScene")
			return false

	_traveling = true
	# The player stays put while the scene changes under them.
	InputLock.lock(&"travel")
	_travels_started += 1
	var travel := _travels_started
	_pending_scene_path = scene_path
	_pending_spawn_id = spawn_id
	travel_started.emit(scene_path, spawn_id)
	if headless:
		var change_error := get_tree().change_scene_to_packed(packed)
		if change_error != OK:
			_fail_pending_travel("Scene change failed (%d)" % change_error)
			return false
	else:
		var transition := get_node_or_null("/root/Transition")
		if transition == null or not transition.has_method("change_scene"):
			_fail_pending_travel("Transition service is unavailable")
			return false
		if not bool(transition.call("change_scene", scene_path)):
			_fail_pending_travel("Another scene change is under way")
			return false
	# A change that fails at once (with no fade to wait for) ended the travel.
	return _travels_ended < travel

func _on_scene_changed() -> void:
	if not _traveling:
		return
	await get_tree().process_frame
	_apply_pending_spawn()
	var scene_path := _pending_scene_path
	var spawn_id := _pending_spawn_id
	_pending_scene_path = ""
	_pending_spawn_id = &""
	_traveling = false
	_portal_grace_until_msec = Time.get_ticks_msec() + ARRIVAL_PORTAL_GRACE_MSEC
	_end_travel(true)
	travel_finished.emit(scene_path, spawn_id)
	travel_ended.emit(true)

func _on_scene_change_failed(path: String) -> void:
	if _traveling and path == _pending_scene_path:
		_fail_pending_travel("Scene change failed")

func _fail_pending_travel(reason: String) -> void:
	var scene_path := _pending_scene_path
	var spawn_id := _pending_spawn_id
	_pending_scene_path = ""
	_pending_spawn_id = &""
	_traveling = false
	_end_travel(false)
	travel_failed.emit(scene_path, spawn_id, reason)
	travel_ended.emit(false)
	GameEvents.toast("Travel failed")

func _end_travel(arrived: bool) -> void:
	InputLock.unlock(&"travel")
	_travels_ended = _travels_started
	_last_arrived = arrived

func _apply_pending_spawn() -> void:
	if _pending_spawn_id == &"":
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for node: Node in get_tree().get_nodes_in_group("world_spawn_point"):
		var spawn := node as WorldSpawnPoint
		if spawn != null and spawn.spawn_id == _pending_spawn_id:
			player.global_position = spawn.global_position
			return
