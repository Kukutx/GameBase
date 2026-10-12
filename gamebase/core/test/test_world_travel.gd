extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const SCENE_DIRECTORY := "user://test_world_travel"
const LOCATION := &"fixture_cellar"
const ENTRY := &"fixture_entry"

var _scene_path := SCENE_DIRECTORY.path_join("fixture_cellar.tscn")

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == _scene_path:
		get_tree().unload_current_scene()
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

	# The transition finds it is no scene, at once or once it has loaded.
	if bool(travel.call("_travel_scene", not_a_scene, &"bad_spawn")):
		assert_false(await travel.travel_ended)
	assert_false(travel.is_traveling())
	assert_eq(travel.get_pending_spawn_id(), &"")
	assert_false(InputLock.is_held(&"travel"))
	assert_eq(failures.size(), 1)
	assert_eq(String(failures[0].get("scene", "")), not_a_scene)
	assert_string_contains(String(failures[0].get("reason", "")), "Scene change failed")
	assert_push_warning("Transition: scene change failed")
	await Transition.wait_until_clear()

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
	assert_eq(_location_problems(registry), PackedStringArray())

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

func test_going_to_a_location_waits_until_the_player_stands_in_it() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	assert_eq(ResourceSaver.save(_location_scene(), _scene_path), OK)
	var location := WorldLocationData.new()
	location.id = LOCATION
	location.display_name = "Cellar"
	location.scene_path = _scene_path
	location.default_spawn_id = ENTRY
	ContentFixture.use(self, [location]).find_problems()
	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	var ended: Array[bool] = []
	travel.travel_ended.connect(func(arrived: bool) -> void: ended.append(arrived))

	assert_true(await travel.go_to(LOCATION))
	assert_false(travel.is_traveling())
	assert_eq(get_tree().current_scene.scene_file_path, _scene_path)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	assert_eq(player.global_position, Vector2(40, 24), "the player stands at the spawn point")
	var camera := player.get_node("Camera") as GameCamera
	assert_eq(camera.get_screen_center_position(), Vector2(40, 24), "and the view is on them at once")
	assert_false(await travel.go_to(&"removed_future_location"), "a travel that cannot start")
	assert_eq(ended, [true], "only a travel that started ends")

func test_a_travel_carries_its_parameters_and_enters_the_region() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	assert_eq(ResourceSaver.save(_location_scene(), _scene_path), OK)
	var region := RegionData.new()
	region.id = &"fixture_valley"
	region.display_name = "Valley"
	var location := WorldLocationData.new()
	location.id = LOCATION
	location.scene_path = _scene_path
	location.default_spawn_id = ENTRY
	location.region_id = &"fixture_missing_region"
	var registry := ContentFixture.use(self, [region, location])
	assert_eq(_location_problems(registry), PackedStringArray(["location '%s' belongs to unknown region 'fixture_missing_region'" % LOCATION]))
	location.region_id = region.id
	assert_eq(_location_problems(registry), PackedStringArray())
	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	watch_signals(travel)

	var params := {"floor": 12}
	assert_true(await travel.go_to(LOCATION, &"", params))
	params["floor"] = 1
	assert_eq(travel.get_params(), {"floor": 12}, "what the travel carried, as it was")
	assert_eq(travel.get_region_id(), &"fixture_valley")
	assert_signal_emitted_with_parameters(travel, "region_changed", [&"fixture_valley", &""])
	assert_true(GameRules.check("REGION fixture_valley"))
	assert_false(GameRules.check("REGION fixture_valley", {"location_id": "removed_future_location"}))
	assert_eq(GameRules.validate_query("REGION fixture_valley"), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_query("REGION fixture_coast")), "unknown region 'fixture_coast'")
	assert_true(travel.travel_to(LOCATION, &"", {"floor": 13}))
	assert_eq(travel.get_params(), {"floor": 13}, "the travel under way")
	# The scene of the travel could not open.
	travel.call("_on_scene_change_failed", _scene_path)
	assert_eq(travel.get_params(), {"floor": 12}, "a failed travel leaves those of the last arrival")
	await get_tree().scene_changed
	assert_true(await travel.go_to(LOCATION))
	assert_eq(travel.get_params(), {}, "a travel that carried nothing")
	assert_signal_emit_count(travel, "region_changed", 1, "the player stayed in the region")

	# A load opens its scene without a travel.
	travel.reset()
	assert_eq(travel.get_region_id(), &"")
	get_tree().change_scene_to_file(_scene_path)
	await get_tree().scene_changed
	assert_eq(travel.get_region_id(), &"fixture_valley", "the loaded scene's region is entered")
	assert_signal_emit_count(travel, "region_changed", 2)

func test_a_travel_started_as_the_last_one_arrives_waits_for_its_own_arrival() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	assert_eq(ResourceSaver.save(_location_scene(), _scene_path), OK)
	var location := WorldLocationData.new()
	location.id = LOCATION
	location.display_name = "Cellar"
	location.scene_path = _scene_path
	location.default_spawn_id = ENTRY
	ContentFixture.use(self, [location]).find_problems()
	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	var results: Array[bool] = []
	# Someone travels on the moment the player arrives.
	var travel_on := func(_scene_path: String, _spawn_id: StringName) -> void:
		results.append(await travel.go_to(LOCATION))
	travel.travel_finished.connect(travel_on, CONNECT_ONE_SHOT)

	assert_true(travel.travel_to(LOCATION))
	await travel.travel_ended
	assert_true(travel.is_traveling(), "the second travel is under way")
	assert_eq(results, [] as Array[bool], "its wait did not end with the first travel")
	await travel.wait_until_arrived()
	# The second travel's own wait may resume after this one.
	await get_tree().process_frame
	assert_eq(results, [true] as Array[bool])
	assert_false(travel.is_traveling())

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

func test_an_interactive_portal_checks_where_it_leads_and_stays_put_when_it_cannot_go() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	assert_eq(ResourceSaver.save(_location_scene(), _scene_path), OK)
	var location := WorldLocationData.new()
	location.id = LOCATION
	location.scene_path = _scene_path
	location.default_spawn_id = ENTRY
	var registry := ContentFixture.use(self, [location])
	var portal := _interactive_portal()
	portal.target_location_id = LOCATION
	assert_eq(portal.find_scene_problems(registry, location), PackedStringArray(), "the default spawn point of the target")
	portal.target_spawn_id = &"fixture_missing"
	assert_eq(portal.find_scene_problems(registry, location), PackedStringArray(["portal '%s' leads to spawn 'fixture_missing' of '%s', which does not exist" % [portal.name, LOCATION]]))
	portal.target_location_id = &"removed_future_location"
	assert_eq(portal.find_scene_problems(registry, null), PackedStringArray(["portal '%s' leads to unknown location 'removed_future_location'" % portal.name]), "a placed building's portal stands in no location")
	watch_signals(portal)
	var toasts: Array[String] = []
	var record := func(message: String) -> void: toasts.append(message)
	GameEvents.toast_requested.connect(record)
	portal.interactable.interact(null)
	GameEvents.toast_requested.disconnect(record)
	assert_signal_not_emitted(portal, "about_to_travel")
	assert_eq(toasts, ["That way is closed for now"])
	assert_false(WorldTravel.is_traveling())

func _interactive_portal() -> InteractivePortal:
	var portal := InteractivePortal.new()
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	portal.add_child(interactable)
	add_child_autofree(portal)
	return portal

## A location scene with the player, whose camera follows them, and one spawn
## point, `ENTRY`.
static func _location_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "FixtureCellar"
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group(&"player", true)
	root.add_child(player)
	player.owner = root
	var camera := GameCamera.new()
	camera.name = "Camera"
	player.add_child(camera)
	camera.owner = root
	var spawn := WorldSpawnPoint.new()
	spawn.name = "Entry"
	spawn.spawn_id = ENTRY
	spawn.position = Vector2(40, 24)
	root.add_child(spawn)
	spawn.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

# The problems of the fixture's locations: the running game's own settings
# (its weather, say) may name content the fixture leaves out.
func _location_problems(registry: ContentRegistry) -> PackedStringArray:
	return PackedStringArray(Array(registry.find_problems()).filter(
		func(problem: String) -> bool: return problem.contains("location")))
