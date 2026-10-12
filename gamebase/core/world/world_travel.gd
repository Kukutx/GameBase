class_name WorldTravelService
extends Node

## Moves the player from one location (`WorldLocationData`) to another: it
## changes to the location's scene behind the `Transition` fade and puts the
## player on the named spawn point (`WorldSpawnPoint`), or the location's default
## one, with the view on them at once (`place_player()`).
##
## One travel runs at a time, and it holds the player's controls (`InputLock`,
## reason `travel`) until the new scene is in place; a portal (`ScenePortal`)
## does not take the player again for a moment after they arrive. A travel to an
## unknown location or spawn fails with `travel_failed` and a toast.
## `travel_finished` fires on arrival, which `AutoSave` follows. The service
## saves nothing; the save records the location itself.
##
## A travel may carry parameters for the place it leads to (`travel_to(...,
## {"floor": 12})`): its scene reads them with `get_params()` from its
## `_ready()` on. Arriving in a location of another region (`RegionData`)
## fires `region_changed` first, also when a scene changes without a travel
## (a load). A load and the title forget the last travel (`reset()`).

signal travel_started(scene_path: String, spawn_id: StringName)
signal travel_finished(scene_path: String, spawn_id: StringName)
signal travel_failed(scene_path: String, spawn_id: StringName, reason: String)
## Emitted when a travel that started ends: `arrived` after `travel_finished`,
## not after `travel_failed`.
signal travel_ended(arrived: bool)
## Emitted on arrival in a location of another region than the last one (an
## empty id for a location of none).
signal region_changed(region_id: StringName, previous_region_id: StringName)

var _pending_spawn_id: StringName = &""
var _pending_scene_path := ""
var _params: Dictionary = {}
# The parameters of the last travel that arrived, back in place when one fails.
var _arrived_params: Dictionary = {}
var _region_id: StringName = &""
var _traveling := false
var _portal_grace_until_msec := 0
# Travels that started, and that ended, so far; `go_to` waits for its own.
var _travels_started := 0
var _travels_ended := 0
var _last_arrived := false

const ARRIVAL_PORTAL_GRACE_MSEC := 450

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	Transition.scene_change_failed.connect(_on_scene_change_failed)

func can_enter_portal() -> bool:
	return not _traveling and Time.get_ticks_msec() >= _portal_grace_until_msec

func is_traveling() -> bool:
	return _traveling

func get_pending_spawn_id() -> StringName:
	return _pending_spawn_id

## The parameters of the travel under way, or else of the last one that
## arrived: a copy, empty for a travel that carried none.
func get_params() -> Dictionary:
	return _params.duplicate(true)

## The region of the location the player is in; empty for none.
func get_region_id() -> StringName:
	return _region_id

## Forgets the last travel's parameters and region, before a scene change that
## is no travel (a load, the title): the scene that opens reads no parameters,
## and its region is entered from none.
func reset() -> void:
	if _traveling:
		return
	_params = {}
	_arrived_params = {}
	_region_id = &""

func can_travel_to(location_id: StringName, spawn_id: StringName = &"") -> bool:
	if _traveling:
		return false
	var location := WorldLocationData.find(location_id)
	if location == null or location.scene_path.is_empty() or not ResourceLoader.exists(location.scene_path):
		return false
	var target_spawn := spawn_id if spawn_id != &"" else location.default_spawn_id
	if target_spawn == &"" or not ContentRegistry.active.has_location_spawn(location_id, target_spawn):
		return false
	return not Transition.is_covering()

func travel_to(location_id: StringName, spawn_id: StringName = &"", params: Dictionary = {}) -> bool:
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
	return _travel_scene(location.scene_path, target_spawn, params)

## Travels as `travel_to` does and waits until this travel ends: true once
## the player stands in the location, false when it could not start or failed.
## The screen may still clear after it (`Transition.wait_until_clear()`).
func go_to(location_id: StringName, spawn_id: StringName = &"", params: Dictionary = {}) -> bool:
	if not travel_to(location_id, spawn_id, params):
		return false
	var travel := _travels_started
	while _travels_ended < travel:
		await travel_ended
	var arrived := _last_arrived
	await _leave_signal()
	return arrived

## Waits until the travel under way, if any, ends.
func wait_until_arrived() -> void:
	if not _traveling:
		return
	while _traveling:
		await travel_ended
	await _leave_signal()

# Waits a frame, so that a wait resumes after the signal that ended it rather
# than inside it: what waited may then free nodes or travel on freely.
func _leave_signal() -> void:
	await get_tree().process_frame

func _travel_scene(scene_path: String, spawn_id: StringName = &"", params: Dictionary = {}) -> bool:
	if _traveling:
		return false
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		travel_failed.emit(scene_path, spawn_id, "Travel scene is unavailable")
		return false
	_traveling = true
	# The player stays put while the scene changes under them.
	InputLock.lock(&"travel")
	_travels_started += 1
	var travel := _travels_started
	_pending_scene_path = scene_path
	_pending_spawn_id = spawn_id
	_params = params.duplicate(true)
	travel_started.emit(scene_path, spawn_id)
	if not Transition.change_scene(scene_path):
		_fail_pending_travel("Another scene change is under way")
		return false
	# A change that fails at once (with no fade to wait for) ended the travel.
	return _travels_ended < travel

func _on_scene_changed() -> void:
	if not _traveling:
		_enter_region()
		return
	await get_tree().process_frame
	_apply_pending_spawn()
	var scene_path := _pending_scene_path
	var spawn_id := _pending_spawn_id
	_pending_scene_path = ""
	_pending_spawn_id = &""
	_traveling = false
	_portal_grace_until_msec = Time.get_ticks_msec() + ARRIVAL_PORTAL_GRACE_MSEC
	_arrived_params = _params
	_end_travel(true)
	_enter_region()
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
	_params = _arrived_params
	_end_travel(false)
	travel_failed.emit(scene_path, spawn_id, reason)
	travel_ended.emit(false)
	GameEvents.toast("Travel failed")

func _enter_region() -> void:
	var location := WorldLocationData.find_current(get_tree())
	var region_id := location.region_id if location != null else &""
	if region_id == _region_id:
		return
	var previous := _region_id
	_region_id = region_id
	region_changed.emit(region_id, previous)

func _end_travel(arrived: bool) -> void:
	InputLock.unlock(&"travel")
	_travels_ended = _travels_started
	_last_arrived = arrived

## Puts the player at `at` and the view on them at once (`GameCamera.snap_all()`),
## rather than sweeping it across the map: a travel's spawn point, a load.
## False when the scene has no player.
func place_player(at: Vector2) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	player.global_position = at
	GameCamera.snap_all(get_tree())
	return true

func _apply_pending_spawn() -> void:
	var spawn := WorldSpawnPoint.find(get_tree(), _pending_spawn_id) if _pending_spawn_id != &"" else null
	if spawn != null:
		place_player(spawn.global_position)
