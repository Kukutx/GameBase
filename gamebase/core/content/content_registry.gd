class_name ContentRegistry
extends Node

## Indexes the running game's content by kind and id, and checks it.
##
## The registry knows no kind of content beyond the core's own (locations,
## audio cues, minigames). Each module registers the kinds it defines with
## `register_kind()` when it installs (`GameModule.install()`), and any check
## that spans many entries with `register_check()`. `rebuild()` then indexes
## every entry of the game's `ContentPack`s (`GameDefinition.content`) under
## the kind its class is registered as, and reports what is wrong:
## - every entry's own `ContentEntry.find_problems()`;
## - every location's scene: exactly one player, unique spawn points, portals
##   that lead to existing spawn points, and what its nodes report about
##   themselves (`find_scene_problems()`). A node with a
##   `get_persistent_keys() -> PackedStringArray` method names the world state
##   it saves; no two nodes of any locations may share a key;
## - the registered checks, and the controls, weather and module settings of
##   the game's `GameDefinition`.
##
## A scene node takes part in the checks by having a
## `find_scene_problems(registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray`
## method. `location` is the location whose scene holds the node, or null for
## a scene placed at runtime (a placeable's). Each problem reads after the
## node's location ("farm field 'Field' belongs to location 'x'").

## The running game's registry: the `ContentDB` autoload, the first registry to
## enter the tree. Content classes' static `find()` and `find_all()` read it.
static var active: ContentRegistry

## The packs `rebuild()` indexes: the game's `GameDefinition.content`, unless a
## test sets others.
var packs: Array[ContentPack] = []
## Names the content this registry indexed last: it changes with every
## `index()` of any registry, so a cache built from the content keeps it and
## rebuilds when `ContentRegistry.active.revision` differs.
var revision := 0
## Set in a release build (`GameModules`), whose content passed `find_problems()`
## before the export: what the checks proved is then taken as given.
var checked_before_export := false

static var _last_revision := 0

## kind -> the script of its entries.
var _kinds: Dictionary = {}
## script -> kind.
var _kind_by_script: Dictionary = {}
## kind -> {id (String) -> ContentEntry}.
var _entries: Dictionary = {}
var _checks: Array[Callable] = []
var _settings_kinds: Array[Script] = []
## location id -> {spawn id -> number of spawn points with that id}, read
## from the location's scene when first asked for.
var _location_spawn_ids: Dictionary = {}
## kind -> its entries sorted by id, read-only; built when first asked for.
var _sorted_entries: Dictionary = {}
## scene path -> the location whose scene it is; built when first asked for.
var _locations_by_scene: Dictionary = {}

func _init() -> void:
	packs.assign(GameDefinition.current().content)
	register_kind(WorldLocationData.KIND, WorldLocationData)
	register_kind(RegionData.KIND, RegionData)
	register_kind(WeatherData.KIND, WeatherData)
	register_kind(VitalData.KIND, VitalData)
	register_kind(AudioCueData.KIND, AudioCueData)
	register_kind(MiniGameDefinition.KIND, MiniGameDefinition)
	register_kind(TriggerData.KIND, TriggerData)
	register_kind(AchievementData.KIND, AchievementData)

func _enter_tree() -> void:
	if active == null:
		active = self

func _exit_tree() -> void:
	if active == self:
		active = null
	# The checks may hold callables of other autoloads.
	_checks.clear()

## Registers a kind of content: every entry whose class is `entry_script` or
## extends it is indexed as `kind`. Problems name the kind with spaces for its
## underscores ("farm_animal" is "farm animal").
func register_kind(kind: StringName, entry_script: Script) -> void:
	if kind == &"" or entry_script == null:
		push_error("ContentDB: a kind needs a name and a script")
		return
	_kinds[kind] = entry_script
	_kind_by_script[entry_script] = kind
	if not _entries.has(kind):
		_entries[kind] = {}
	_sorted_entries.erase(kind)

## Registers `script`, a module's kind of `ModuleSettings`, so the running
## game's settings of that kind are checked with the content
## (`GameDefinition.find_settings_problems()`), its defaults when the game
## lists none.
func register_settings(script: Script) -> void:
	if script != null and not _settings_kinds.has(script):
		_settings_kinds.append(script)

## Registers a check of the whole content, for what no single entry can tell
## (a graph without cycles, a ladder of tiers): `check.call(registry)` returns
## its problems as complete sentences.
func register_check(check: Callable) -> void:
	if not _checks.has(check):
		_checks.append(check)

## Indexes and checks all content (`index()`, then `find_problems()`); returns
## the problems found, which are also reported with `push_error`. The checks
## open every location's scene, so a release build only indexes (`index()`):
## its content passed them before it shipped.
func rebuild() -> PackedStringArray:
	var problems := index()
	problems.append_array(find_problems())
	for message: String in problems:
		push_error("ContentDB: " + message)
	return problems

## Indexes every entry of `packs` by kind and id. Returns the entries it
## skipped, as problems: an entry of no registered kind, an empty or repeated
## id. Reports nothing itself.
func index() -> PackedStringArray:
	var problems := PackedStringArray()
	for kind: StringName in _kinds:
		_entries[kind] = {}
	_location_spawn_ids.clear()
	_sorted_entries.clear()
	_locations_by_scene.clear()
	_last_revision += 1
	revision = _last_revision
	for pack: ContentPack in packs:
		if pack == null:
			problems.append("the game lists an empty content pack")
			continue
		for entry: ContentEntry in pack.entries:
			if entry == null:
				problems.append("content pack '%s' has an empty entry" % pack.resource_path)
				continue
			var kind := get_kind_of(entry)
			if kind == &"":
				problems.append("'%s' is of no kind of content an installed module registers" % entry.resource_path)
				continue
			var label := get_kind_label(kind)
			if entry.id == &"":
				problems.append("%s resource has an empty id: %s" % [label, entry.resource_path])
				continue
			var by_id: Dictionary = _entries[kind]
			if by_id.has(String(entry.id)):
				problems.append("duplicate %s id '%s'" % [label, entry.id])
				continue
			by_id[String(entry.id)] = entry
	return problems

## Checks the indexed content (see the class description). Returns the
## problems and reports nothing itself.
func find_problems() -> PackedStringArray:
	var problems := GameControls.find_problems(GameControls.of_game(), GameControls.of_modules())
	problems.append_array(GameWeatherSystem.find_problems(GameDefinition.current(), self))
	problems.append_array(GameDefinition.current().find_settings_problems(self, _settings_kinds))
	problems.append_array(InheritanceRule.find_list_problems(GameDefinition.current().inheritance, self))
	problems.append_array(GameCalendar.current().find_problems())
	for kind: StringName in get_kinds():
		for entry: ContentEntry in get_entries(kind):
			problems.append_array(find_entry_problems(entry))
	_check_locations(problems)
	for check: Callable in _checks:
		problems.append_array(check.call(self))
	return problems

## `entry.find_problems()`, each after the entry's kind and id.
func find_entry_problems(entry: ContentEntry) -> PackedStringArray:
	var problems := PackedStringArray()
	var label := get_kind_label(get_kind_of(entry))
	for problem: String in entry.find_problems(self):
		problems.append("%s '%s' %s" % [label, entry.id, problem])
	return problems

## The entry of `kind` with `id`, or null.
func get_entry(kind: StringName, id: StringName) -> ContentEntry:
	return (_entries.get(kind, {}) as Dictionary).get(String(id)) as ContentEntry

func has_entry(kind: StringName, id: StringName) -> bool:
	return get_entry(kind, id) != null

## Every entry of `kind`, sorted by id. The array is read-only and shared by
## every caller until the next `index()`.
func get_entries(kind: StringName) -> Array:
	var cached: Variant = _sorted_entries.get(kind)
	if cached != null:
		return cached
	var by_id: Dictionary = _entries.get(kind, {})
	var ids: Array = by_id.keys()
	ids.sort()
	var result: Array = []
	for id: String in ids:
		result.append(by_id[id])
	result.make_read_only()
	_sorted_entries[kind] = result
	return result

## The location whose scene is `scene_path`, or null. When several share it
## (a problem `find_problems()` reports), the one with the first id.
func get_location_for_scene(scene_path: String) -> WorldLocationData:
	if scene_path.is_empty():
		return null
	if _locations_by_scene.is_empty():
		for location: WorldLocationData in _locations():
			if not _locations_by_scene.has(location.scene_path):
				_locations_by_scene[location.scene_path] = location
	return _locations_by_scene.get(scene_path) as WorldLocationData

## The registered kinds, sorted.
func get_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	kinds.assign(_kinds.keys())
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return kinds

## The script of the entries of `kind`, or null.
func get_kind_script(kind: StringName) -> Script:
	return _kinds.get(kind) as Script

## The kind `entry` is indexed as, or an empty name when its class is of no
## registered kind.
func get_kind_of(entry: ContentEntry) -> StringName:
	var script := entry.get_script() as Script
	while script != null:
		if _kind_by_script.has(script):
			return _kind_by_script[script]
		script = script.get_base_script()
	return &""

## How problems name `kind`: "farm_animal" is "farm animal".
static func get_kind_label(kind: StringName) -> String:
	return String(kind).replace("_", " ")

## Whether the scene of `location_id` has exactly one spawn point `spawn_id`.
## The scene's spawn points are read from its node list the first time, without
## instancing it; content `checked_before_export` is taken at its word, since
## reading the scene would load it before its travel's fade.
func has_location_spawn(location_id: StringName, spawn_id: StringName) -> bool:
	if location_id == &"" or spawn_id == &"":
		return false
	if checked_before_export:
		return get_entry(WorldLocationData.KIND, location_id) != null
	return int(_get_spawn_counts(location_id).get(String(spawn_id), 0)) == 1

## The spawn points of `packed`, read from its node list without instancing it:
## spawn id (String) -> how many spawn points have it. Spawn points inside
## scenes it instances count too.
static func count_scene_spawns(packed: PackedScene) -> Dictionary:
	var counts: Dictionary = {}
	if packed != null:
		_count_state_spawns(packed.get_state(), {}, counts)
	return counts

# `root_overrides` are what the node instancing this scene sets on its root.
static func _count_state_spawns(state: SceneState, root_overrides: Dictionary, counts: Dictionary) -> void:
	for node in range(state.get_node_count()):
		var properties: Dictionary = {}
		for property in range(state.get_node_property_count(node)):
			properties[state.get_node_property_name(node, property)] = state.get_node_property_value(node, property)
		if node == 0:
			properties.merge(root_overrides, true)
		var instance := state.get_node_instance(node)
		if instance != null:
			_count_state_spawns(instance.get_state(), properties, counts)
			continue
		var script := properties.get(&"script") as Script
		if not _extends_script(script, WorldSpawnPoint):
			continue
		var spawn_id: Variant = properties.get(&"spawn_id", script.get_property_default_value(&"spawn_id"))
		var key := String(spawn_id) if spawn_id != null else ""
		counts[key] = int(counts.get(key, 0)) + 1

static func _extends_script(script: Script, base: Script) -> bool:
	while script != null:
		if script == base:
			return true
		script = script.get_base_script()
	return false

func _get_spawn_counts(location_id: StringName) -> Dictionary:
	var key := String(location_id)
	if not _location_spawn_ids.has(key):
		var counts: Dictionary = {}
		var location := get_entry(WorldLocationData.KIND, location_id) as WorldLocationData
		if location != null and not location.scene_path.is_empty() and ResourceLoader.exists(location.scene_path):
			counts = count_scene_spawns(load(location.scene_path) as PackedScene)
		_location_spawn_ids[key] = counts
	return _location_spawn_ids[key]

## What the nodes under `root` report about themselves (see the class
## description); `location` is the location whose scene `root` is, or null.
func find_scene_problems(root: Node, location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	if root.has_method(&"find_scene_problems"):
		problems.append_array(root.call(&"find_scene_problems", self, location))
	for child: Node in root.get_children():
		problems.append_array(find_scene_problems(child, location))
	return problems

## The cycles of `graph` (node -> Array of the nodes it depends on) as
## sentences; `label` names the kind of node. An edge to a node outside the
## graph is ignored: the entry that has it reports the unknown reference.
static func find_dependency_cycles(graph: Dictionary, label: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var state: Dictionary = {}
	var stack: Array[String] = []
	var reported: Dictionary = {}
	var nodes: Array[String] = []
	for raw_node: Variant in graph.keys():
		nodes.append(String(raw_node))
	nodes.sort()
	for node: String in nodes:
		if int(state.get(node, 0)) == 0:
			_visit_dependency_node(node, graph, state, stack, reported, label, problems)
	return problems

static func _visit_dependency_node(node: String, graph: Dictionary, state: Dictionary, stack: Array[String], reported: Dictionary, label: String, problems: PackedStringArray) -> void:
	state[node] = 1
	stack.append(node)
	var neighbors: Array[String] = []
	var raw_neighbors: Variant = graph.get(node, [])
	if raw_neighbors is Array:
		for raw_neighbor: Variant in raw_neighbors:
			neighbors.append(String(raw_neighbor))
	neighbors.sort()
	for neighbor: String in neighbors:
		if not graph.has(neighbor):
			continue
		var neighbor_state := int(state.get(neighbor, 0))
		if neighbor_state == 0:
			_visit_dependency_node(neighbor, graph, state, stack, reported, label, problems)
		elif neighbor_state == 1:
			var cycle_nodes: Array[String] = stack.slice(stack.find(neighbor))
			var signature_nodes := cycle_nodes.duplicate()
			signature_nodes.sort()
			var signature := "|".join(PackedStringArray(signature_nodes))
			if reported.has(signature):
				continue
			reported[signature] = true
			var cycle_path := cycle_nodes.duplicate()
			cycle_path.append(neighbor)
			problems.append("%s dependency cycle: %s" % [label, " -> ".join(PackedStringArray(cycle_path))])
	stack.pop_back()
	state[node] = 2

func _check_locations(problems: PackedStringArray) -> void:
	# First pass: load every scene once and record its spawn points, so portals
	# can be checked against any target location in the second pass.
	var scene_paths: Dictionary = {}
	var roots: Dictionary = {}
	var locations := _locations()
	for location: WorldLocationData in locations:
		if location.scene_path.is_empty() or not ResourceLoader.exists(location.scene_path):
			problems.append("location '%s' references missing scene '%s'" % [location.id, location.scene_path])
			continue
		var packed := load(location.scene_path) as PackedScene
		if packed == null:
			problems.append("location '%s' scene '%s' is not a PackedScene" % [location.id, location.scene_path])
			continue
		if scene_paths.has(location.scene_path):
			problems.append("locations '%s' and '%s' share scene path '%s'" % [scene_paths[location.scene_path], location.id, location.scene_path])
		else:
			scene_paths[location.scene_path] = String(location.id)
		var root := packed.instantiate()
		if root == null:
			continue
		roots[String(location.id)] = root
		var spawn_counts: Dictionary = {}
		_collect_spawn_counts(root, spawn_counts)
		# Travel reads the spawn points from the node list; it must see these.
		if count_scene_spawns(packed) != spawn_counts:
			problems.append("location '%s' scene '%s' has spawn points its node list does not show; place each as a WorldSpawnPoint node of its own, with its spawn_id set there rather than overridden from an inheriting or instancing scene" % [location.id, location.scene_path])
		_location_spawn_ids[String(location.id)] = spawn_counts
	# persistent key -> "location 'x' node 'y'"
	var key_owners: Dictionary = {}
	for location: WorldLocationData in locations:
		if not roots.has(String(location.id)):
			continue
		var root: Node = roots[String(location.id)]
		var spawn_counts: Dictionary = _location_spawn_ids[String(location.id)]
		var player_count := _count_group_nodes(root, &"player")
		if player_count != 1:
			problems.append("location '%s' scene must contain exactly one player node, found %d" % [location.id, player_count])
		for raw_spawn_id: Variant in spawn_counts.keys():
			var spawn_id := String(raw_spawn_id)
			if spawn_id.is_empty():
				problems.append("location '%s' scene has a spawn point with an empty id" % location.id)
			elif int(spawn_counts[raw_spawn_id]) > 1:
				problems.append("location '%s' scene has duplicate spawn id '%s'" % [location.id, spawn_id])
		if location.default_spawn_id == &"":
			problems.append("location '%s' has an empty default spawn id" % location.id)
		elif not spawn_counts.has(String(location.default_spawn_id)):
			problems.append("location '%s' default spawn '%s' is missing from scene '%s'" % [location.id, location.default_spawn_id, location.scene_path])
		var portals: Array[ScenePortal] = []
		_collect_portals(root, portals)
		for portal: ScenePortal in portals:
			_check_portal(location, portal, problems)
		for problem: String in find_scene_problems(root, location):
			problems.append("location '%s' %s" % [location.id, problem])
		_collect_persistent_keys(root, location, key_owners, problems)
	for root: Node in roots.values():
		root.free()

func _locations() -> Array[WorldLocationData]:
	var result: Array[WorldLocationData] = []
	result.assign(get_entries(WorldLocationData.KIND))
	return result

func _check_portal(source_location: WorldLocationData, portal: ScenePortal, problems: PackedStringArray) -> void:
	var portal_name := String(portal.name)
	if portal.target_location_id == &"":
		problems.append("location '%s' portal '%s' must use a stable target location id" % [source_location.id, portal_name])
		return
	var target_location := get_entry(WorldLocationData.KIND, portal.target_location_id) as WorldLocationData
	if target_location == null:
		problems.append("location '%s' portal '%s' references unknown target location '%s'" % [source_location.id, portal_name, portal.target_location_id])
		return
	if not _location_spawn_ids.has(String(target_location.id)):
		problems.append("location '%s' portal '%s' target location '%s' has no valid PackedScene" % [source_location.id, portal_name, portal.target_location_id])
		return
	var resolved_spawn := portal.target_spawn_id if portal.target_spawn_id != &"" else target_location.default_spawn_id
	var target_spawns: Dictionary = _location_spawn_ids[String(target_location.id)]
	if resolved_spawn == &"" or not target_spawns.has(String(resolved_spawn)):
		problems.append("location '%s' portal '%s' target spawn '%s' is missing from location '%s'" % [source_location.id, portal_name, resolved_spawn, portal.target_location_id])

func _collect_persistent_keys(node: Node, location: WorldLocationData, key_owners: Dictionary, problems: PackedStringArray) -> void:
	if node.has_method(&"get_persistent_keys"):
		var holder := "location '%s' node '%s'" % [location.id, node.name]
		for key: String in node.call(&"get_persistent_keys"):
			if key_owners.has(key):
				problems.append("persistent state key '%s' is shared by %s and %s" % [key, key_owners[key], holder])
			else:
				key_owners[key] = holder
	for child: Node in node.get_children():
		_collect_persistent_keys(child, location, key_owners, problems)

func _collect_spawn_counts(node: Node, counts: Dictionary) -> void:
	if node is WorldSpawnPoint:
		var key := String((node as WorldSpawnPoint).spawn_id)
		counts[key] = int(counts.get(key, 0)) + 1
	for child: Node in node.get_children():
		_collect_spawn_counts(child, counts)

func _collect_portals(node: Node, portals: Array[ScenePortal]) -> void:
	if node is ScenePortal:
		portals.append(node as ScenePortal)
	for child: Node in node.get_children():
		_collect_portals(child, portals)

func _count_group_nodes(node: Node, group: StringName) -> int:
	var count := 1 if node.is_in_group(group) else 0
	for child: Node in node.get_children():
		count += _count_group_nodes(child, group)
	return count
