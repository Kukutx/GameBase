extends GutTest

## The content registry's own mechanics, on content the test builds: the kinds
## the core registers, which entries `index()` takes, how content is found,
## and the cycle detector the modules' content checks share.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

## An entry of a class no module registers as a kind of content.
class _UnregisteredEntry extends ContentEntry:
	pass

func test_the_core_registers_its_own_kinds_of_content() -> void:
	for kind: StringName in [WorldLocationData.KIND, AudioCueData.KIND, MiniGameDefinition.KIND]:
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
