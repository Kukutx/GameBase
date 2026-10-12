extends GutTest

## The content registry's own mechanics, on content the test builds: the kinds
## the core registers, which entries `index()` takes, how content is found,
## and the cycle detector the modules' content checks share.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

const SCENE_DIRECTORY := "user://test_content_registry"

## An entry of a class no module registers as a kind of content.
class _UnregisteredEntry extends ContentEntry:
	pass

func after_each() -> void:
	if not DirAccess.dir_exists_absolute(SCENE_DIRECTORY):
		return
	for file: String in DirAccess.get_files_at(SCENE_DIRECTORY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))

func test_the_core_registers_its_own_kinds_of_content() -> void:
	for kind: StringName in [WorldLocationData.KIND, RegionData.KIND, WeatherData.KIND, VitalData.KIND, AudioCueData.KIND, MiniGameDefinition.KIND, TriggerData.KIND, AchievementData.KIND, HintData.KIND]:
		assert_true(ContentDB.get_kinds().has(kind), "the core registers kind '%s'" % kind)

func test_unknown_ids_return_null() -> void:
	var location := WorldLocationData.new()
	location.id = &"fixture_meadow"
	var cue := AudioCueData.new()
	cue.id = &"fixture_chime"
	ContentFixture.use(self, [location, cue])
	assert_eq(WorldLocationData.find(&"fixture_meadow"), location)
	assert_eq(AudioCueData.find(&"fixture_chime"), cue)
	assert_null(WorldLocationData.find(&"fixture_missing"))
	assert_null(AudioCueData.find(&"fixture_missing"))

func test_an_entry_of_no_registered_kind_is_not_indexed() -> void:
	var registry := ContentRegistry.new()
	autofree(registry)
	var orphan := _UnregisteredEntry.new()
	orphan.id = &"fixture_orphan"
	orphan.resource_path = "res://fixture/orphan_entry.tres"
	var location := WorldLocationData.new()
	var pack := ContentPack.new()
	pack.entries = [orphan, location]
	registry.packs = [pack]
	var problems := registry.index()
	assert_eq(problems, PackedStringArray([
		"'res://fixture/orphan_entry.tres' is of no kind of content an installed module registers",
		"location resource has an empty id: ",
	]))
	assert_eq(registry.get_kind_of(orphan), &"")
	for kind: StringName in registry.get_kinds():
		assert_eq(registry.get_entries(kind), [], "nothing is indexed as kind '%s'" % kind)

func test_entries_are_sorted_once_and_shared_until_the_content_is_indexed_again() -> void:
	var second := WorldLocationData.new()
	second.id = &"fixture_second"
	var first := WorldLocationData.new()
	first.id = &"fixture_first"
	var registry := ContentFixture.use(self, [second, first])
	var entries := registry.get_entries(WorldLocationData.KIND)
	assert_eq(entries, [first, second])
	assert_true(entries.is_read_only(), "every caller shares it")
	assert_true(is_same(entries, registry.get_entries(WorldLocationData.KIND)))
	var revision := registry.revision
	registry.index()
	assert_ne(registry.revision, revision, "indexing again names new content")
	assert_false(is_same(entries, registry.get_entries(WorldLocationData.KIND)))

func test_a_location_is_found_by_its_scene() -> void:
	var meadow := WorldLocationData.new()
	meadow.id = &"fixture_meadow"
	meadow.scene_path = "res://fixture/meadow.tscn"
	ContentFixture.use(self, [meadow])
	assert_eq(WorldLocationData.find_for_scene("res://fixture/meadow.tscn"), meadow)
	assert_null(WorldLocationData.find_for_scene("res://fixture/elsewhere.tscn"))
	assert_null(WorldLocationData.find_for_scene(""))

func test_spawn_points_are_read_from_a_scene_without_instancing_it() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	# A spawn point scene with one more spawn point inside it.
	var pier := WorldSpawnPoint.new()
	pier.name = "Pier"
	pier.spawn_id = &"pier"
	var nested := WorldSpawnPoint.new()
	nested.name = "Nested"
	nested.spawn_id = &"nested"
	pier.add_child(nested)
	nested.owner = pier
	var pier_scene := PackedScene.new()
	assert_eq(pier_scene.pack(pier), OK)
	pier.free()
	var pier_path := SCENE_DIRECTORY.path_join("pier.tscn")
	assert_eq(ResourceSaver.save(pier_scene, pier_path), OK)
	# A harbor with a gate, and the pier scene placed as the dock.
	var harbor := Node2D.new()
	harbor.name = "Harbor"
	var gate := WorldSpawnPoint.new()
	gate.name = "Gate"
	gate.spawn_id = &"gate"
	harbor.add_child(gate)
	gate.owner = harbor
	var dock := (load(pier_path) as PackedScene).instantiate() as WorldSpawnPoint
	dock.name = "Dock"
	dock.spawn_id = &"dock"
	harbor.add_child(dock)
	dock.owner = harbor
	var harbor_scene := PackedScene.new()
	assert_eq(harbor_scene.pack(harbor), OK)
	harbor.free()
	var harbor_path := SCENE_DIRECTORY.path_join("harbor.tscn")
	assert_eq(ResourceSaver.save(harbor_scene, harbor_path), OK)

	var harbor_scene_loaded := load(harbor_path) as PackedScene
	assert_eq(ContentRegistry.count_scene_spawns(harbor_scene_loaded), {"gate": 1, "dock": 1, "nested": 1})
	var location := WorldLocationData.new()
	location.id = &"fixture_harbor"
	location.scene_path = harbor_path
	location.default_spawn_id = &"gate"
	var registry := ContentFixture.use(self, [location])
	# Indexed but not checked: travel reads the spawn points when it needs them.
	assert_true(registry.has_location_spawn(&"fixture_harbor", &"dock"))
	assert_true(registry.has_location_spawn(&"fixture_harbor", &"nested"))
	assert_false(registry.has_location_spawn(&"fixture_harbor", &"pier"), "the dock renames the pier")
	assert_false(registry.has_location_spawn(&"fixture_harbor", &"missing"))
	registry.checked_before_export = true
	assert_true(registry.has_location_spawn(&"fixture_harbor", &"missing"), "a release build takes its checked content at its word")
	assert_false(registry.has_location_spawn(&"fixture_nowhere", &"gate"))

func test_a_spawn_point_the_node_list_does_not_show_is_a_problem() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	# A root whose script adds the spawn point when it is created: the scene's
	# node list holds the root alone.
	var field := Node2D.new()
	field.name = "Field"
	field.set_script(load("res://gamebase/core/test/fixtures/spawn_from_code.gd"))
	var scene := PackedScene.new()
	assert_eq(scene.pack(field), OK)
	field.free()
	var path := SCENE_DIRECTORY.path_join("field.tscn")
	assert_eq(ResourceSaver.save(scene, path), OK)
	var location := WorldLocationData.new()
	location.id = &"fixture_field"
	location.scene_path = path
	location.default_spawn_id = &"gate"
	var registry := ContentFixture.use(self, [location])
	var problems := registry.find_problems()
	assert_true(Array(problems).any(func(problem: String) -> bool: return problem.begins_with("location 'fixture_field'") and problem.contains("node list does not show")), str(problems))

func test_a_game_starts_and_wakes_in_locations_of_its_own() -> void:
	var registry := ContentFixture.use(self, [_location_with_spawn(&"fixture_home", &"bed")])
	var definition := GameDefinition.new()
	assert_eq(definition.find_place_problems(registry), PackedStringArray(["the game names no start location (GameDefinition.start_location_id)"]))
	definition.start_location_id = &"fixture_home"
	assert_eq(definition.find_place_problems(registry), PackedStringArray(), "a game need not name a home")
	definition.home_spawn_id = &"bed"
	assert_eq(definition.find_place_problems(registry), PackedStringArray(["the home spawn 'bed' belongs to no home location (GameDefinition.home_location_id)"]))
	definition.home_location_id = &"fixture_home"
	assert_eq(definition.find_place_problems(registry), PackedStringArray())
	definition.home_spawn_id = &"door"
	assert_eq(definition.find_place_problems(registry), PackedStringArray(["the home spawn 'door' is no spawn point of location 'fixture_home'"]))
	definition.start_location_id = &"fixture_nowhere"
	definition.home_location_id = &"fixture_nowhere"
	assert_eq(definition.find_place_problems(registry), PackedStringArray([
		"the start location 'fixture_nowhere' is no location of the game",
		"the home location 'fixture_nowhere' is no location of the game",
	]))

func test_dependency_cycle_detector_accepts_acyclic_graph_and_ignores_unknown_edges() -> void:
	var graph := {
		"a": ["b"],
		"b": ["c"],
		"c": ["missing_external_reference"],
	}
	assert_eq(ContentRegistry.find_dependency_cycles(graph, "test graph"), PackedStringArray())

func test_dependency_cycle_detector_reports_self_two_node_and_three_node_cycles() -> void:
	assert_eq(ContentRegistry.find_dependency_cycles({"a": ["a"]}, "quest"), PackedStringArray(["quest dependency cycle: a -> a"]))
	assert_eq(ContentRegistry.find_dependency_cycles({"a": ["b"], "b": ["a"]}, "town project"), PackedStringArray(["town project dependency cycle: a -> b -> a"]))
	assert_eq(ContentRegistry.find_dependency_cycles({"a": ["b"], "b": ["c"], "c": ["a"]}, "farm expansion"), PackedStringArray(["farm expansion dependency cycle: a -> b -> c -> a"]))

func test_custom_fields_return_their_value_or_the_default() -> void:
	var location := WorldLocationData.new()
	location.custom_fields = {"rarity": "rare"}
	assert_eq(location.get_custom_field(&"rarity"), "rare")
	assert_eq(location.get_custom_field(&"missing", 3), 3)

# A location whose scene holds one spawn point, `spawn_id`.
func _location_with_spawn(id: StringName, spawn_id: StringName) -> WorldLocationData:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))
	var root := Node2D.new()
	root.name = "Place"
	var spawn := WorldSpawnPoint.new()
	spawn.name = "Spawn"
	spawn.spawn_id = spawn_id
	root.add_child(spawn)
	spawn.owner = root
	var scene := PackedScene.new()
	assert_eq(scene.pack(root), OK)
	root.free()
	var path := SCENE_DIRECTORY.path_join("%s.tscn" % id)
	assert_eq(ResourceSaver.save(scene, path), OK)
	var location := WorldLocationData.new()
	location.id = id
	location.scene_path = path
	location.default_spawn_id = spawn_id
	return location
