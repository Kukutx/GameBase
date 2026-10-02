extends GutTest

func test_invalid_travel_target_never_locks_world_travel() -> void:
	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	var failures: Array[Dictionary] = []
	travel.travel_failed.connect(func(scene_path: String, spawn_id: StringName, reason: String) -> void:
		failures.append({"scene": scene_path, "spawn": String(spawn_id), "reason": reason})
	)

	assert_false(bool(travel.call("_travel_scene", "res://game/data/content_manifest.tres", &"bad_spawn")))
	assert_false(travel.is_traveling())
	assert_eq(travel.get_pending_spawn_id(), &"")
	assert_eq(failures.size(), 1)
	assert_eq(String(failures[0].get("scene", "")), "res://game/data/content_manifest.tres")
	assert_string_contains(String(failures[0].get("reason", "")), "not a PackedScene")

	assert_false(bool(travel.call("_travel_scene", "res://game/world/definitely_missing_scene.tscn", &"missing")))
	assert_false(travel.is_traveling())
	assert_eq(failures.size(), 2)
	assert_string_contains(String(failures[1].get("reason", "")), "unavailable")

func test_unknown_location_reports_failure_without_pending_state() -> void:
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
	var travel := WorldTravelService.new()
	add_child_autofree(travel)
	assert_true(travel.can_travel_to(&"old_mine", &"floor_entry"))
	assert_false(travel.can_travel_to(&"old_mine", &"typo_spawn"))
	var observed := {"count": 0, "reason": ""}
	travel.travel_failed.connect(func(_scene_path: String, _spawn_id: StringName, reason: String) -> void:
		observed["count"] = int(observed["count"]) + 1
		observed["reason"] = reason
	)
	assert_false(travel.travel_to(&"old_mine", &"typo_spawn"))
	assert_false(travel.is_traveling())
	assert_eq(travel.get_pending_spawn_id(), &"")
	assert_eq(int(observed["count"]), 1)
	assert_string_contains(String(observed["reason"]), "Unknown spawn")

func test_portal_reenables_itself_when_travel_cannot_start() -> void:
	var portal := ScenePortal.new()
	portal.target_location_id = &"removed_future_location"
	portal.target_spawn_id = &"spawn"
	portal.enabled = false
	portal.set("_travel_requested", true)
	add_child_autofree(portal)
	portal.call("_start_travel")
	assert_true(portal.enabled)
	assert_false(bool(portal.get("_travel_requested")))
