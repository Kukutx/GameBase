extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const SCENE_DIRECTORY := "user://test_world_travel"
const LOCATION := &"fixture_cellar"
const ENTRY := &"fixture_entry"

var _scene_path := SCENE_DIRECTORY.path_join("fixture_cellar.tscn")

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	if FileAccess.file_exists(_scene_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_scene_path))
	if DirAccess.dir_exists_absolute(SCENE_DIRECTORY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))

func test_invalid_travel_target_never_locks_world_travel() -> void:
	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	var failures: Array[Dictionary] = []
	travel.travel_failed.connect(func(scene_path: String, spawn_id: StringName, reason: String) -> void:
		failures.append({"scene": scene_path, "spawn": String(spawn_id), "reason": reason})
	)
	# A resource that exists but is no scene: this script.
	var not_a_scene := (get_script() as Script).resource_path

	assert_false(bool(travel.call("_travel_scene", not_a_scene, &"bad_spawn")))
	assert_false(travel.is_traveling())
	assert_eq(travel.get_pending_spawn_id(), &"")
	assert_eq(failures.size(), 1)
	assert_eq(String(failures[0].get("scene", "")), not_a_scene)
	assert_string_contains(String(failures[0].get("reason", "")), "not a PackedScene")

	assert_false(bool(travel.call("_travel_scene", "res://gamebase/core/test/definitely_missing_scene.tscn", &"missing")))
	assert_false(travel.is_traveling())
	assert_eq(failures.size(), 2)
	assert_string_contains(String(failures[1].get("reason", "")), "unavailable")

func test_unknown_location_reports_failure_without_pending_state() -> void:
	ContentFixture.use(self, [])
	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	var observed := {"count": 0, "reason": ""}
	travel.travel_failed.connect(func(_scene_path: String, _spawn_id: StringName, reason: String) -> void:
		observed["count"] = int(observed["count"]) + 1
		observed["reason"] = reason
	)
	assert_false(travel.travel_to(&"removed_future_location", &"spawn"))
	assert_false(travel.is_traveling())
	assert_eq(travel.get_pending_spawn_id(), &"")
	assert_eq(int(observed["count"]), 1)
	assert_string_contains(String(observed["reason"]), "Unknown location")

func test_stable_location_travel_rejects_unknown_spawn_before_scene_change() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	assert_eq(ResourceSaver.save(_location_scene(), _scene_path), OK)
	var location := WorldLocationData.new()
	location.id = LOCATION
	location.display_name = "Cellar"
	location.scene_path = _scene_path
	location.default_spawn_id = ENTRY
	var registry := ContentFixture.use(self, [location])
	# Checking the content records each location's spawn points.
	assert_eq(registry.find_problems(), PackedStringArray())

	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	assert_true(travel.can_travel_to(LOCATION, ENTRY))
	assert_false(travel.can_travel_to(LOCATION, &"typo_spawn"))
	var observed := {"count": 0, "reason": ""}
	travel.travel_failed.connect(func(_scene_path: String, _spawn_id: StringName, reason: String) -> void:
		observed["count"] = int(observed["count"]) + 1
		observed["reason"] = reason
	)
	assert_false(travel.travel_to(LOCATION, &"typo_spawn"))
	assert_false(travel.is_traveling())
	assert_eq(travel.get_pending_spawn_id(), &"")
	assert_eq(int(observed["count"]), 1)
	assert_string_contains(String(observed["reason"]), "Unknown spawn")

func test_portal_reenables_itself_when_travel_cannot_start() -> void:
	ContentFixture.use(self, [])
	var portal := ScenePortal.new()
	portal.target_location_id = &"removed_future_location"
	portal.target_spawn_id = &"spawn"
	portal.enabled = false
	portal.set("_travel_requested", true)
	add_child_autofree(portal)
	portal.call("_start_travel")
	assert_true(portal.enabled)
	assert_false(bool(portal.get("_travel_requested")))

## A location scene with the player and one spawn point, `ENTRY`.
static func _location_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "FixtureCellar"
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group(&"player", true)
	root.add_child(player)
	player.owner = root
	var spawn := WorldSpawnPoint.new()
	spawn.name = "Entry"
	spawn.spawn_id = ENTRY
	root.add_child(spawn)
	spawn.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
