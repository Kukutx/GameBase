class_name WorldTravelService
extends Node

signal travel_started(scene_path: String, spawn_id: StringName)
signal travel_finished(scene_path: String, spawn_id: StringName)
signal travel_failed(scene_path: String, spawn_id: StringName, reason: String)

var _pending_spawn_id: StringName = &""
var _pending_scene_path := ""
var _traveling := false
var _portal_grace_until_msec := 0

const ARRIVAL_PORTAL_GRACE_MSEC := 450

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)

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
	if target_spawn == &"" or not ContentDB.has_location_spawn(location_id, target_spawn):
		return false
	if not ResourceLoader.load(location.scene_path) is PackedScene:
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
	if target_spawn == &"" or not ContentDB.has_location_spawn(location_id, target_spawn):
		travel_failed.emit(location.scene_path, target_spawn, "Unknown spawn '%s' for location '%s'" % [target_spawn, location_id])
		GameEvents.toast("Travel spawn is unavailable")
		return false
	return _travel_scene(location.scene_path, target_spawn)

func _travel_scene(scene_path: String, spawn_id: StringName = &"") -> bool:
	if _traveling:
		return false
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		travel_failed.emit(scene_path, spawn_id, "Travel scene is unavailable")
		return false
	var packed := ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		travel_failed.emit(scene_path, spawn_id, "Travel target is not a PackedScene")
		return false

	_traveling = true
	_pending_scene_path = scene_path
	_pending_spawn_id = spawn_id
	travel_started.emit(scene_path, spawn_id)
	if DisplayServer.get_name() == "headless":
		var change_error := get_tree().change_scene_to_packed(packed)
		if change_error != OK:
			_fail_pending_travel("Scene change failed (%d)" % change_error)
			return false
	else:
		var transition := get_node_or_null("/root/Transition")
		if transition == null or not transition.has_method("change_scene"):
			_fail_pending_travel("Transition service is unavailable")
			return false
		transition.call("change_scene", scene_path)
	return true

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
	travel_finished.emit(scene_path, spawn_id)

func _fail_pending_travel(reason: String) -> void:
	var scene_path := _pending_scene_path
	var spawn_id := _pending_spawn_id
	_pending_scene_path = ""
	_pending_spawn_id = &""
	_traveling = false
	travel_failed.emit(scene_path, spawn_id, reason)
	GameEvents.toast("Travel failed")

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
