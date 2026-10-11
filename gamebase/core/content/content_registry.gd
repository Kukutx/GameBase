class_name ContentRegistry
extends Node

## Indexes a game's content definitions by kind and id and validates them.
##
## The registry does not know which kinds of content a game has. A game extends
## it, registers each kind's entries in `_index_content()` with
## `register_entries()` and checks its own references in `_validate_content()`.
## The registry itself owns the kinds the foundation needs (locations and audio
## cues, minigames) and validates location scenes: spawn points, portals and
## the player. It also checks the controls of the game's `GameDefinition`.

const KIND_LOCATION := &"location"
const KIND_AUDIO_CUE := &"audio_cue"
const KIND_MINIGAME := &"minigame"

## kind -> {id -> ContentEntry}. Each inner dictionary is the one
## `register_entries()` returned, so a subclass may keep and read it directly.
var _entries: Dictionary = {}
## location id -> {spawn id -> number of spawn points with that id}.
var _location_spawn_ids: Dictionary = {}

func _ready() -> void:
	rebuild()

## Re-indexes and re-validates all content; returns the problems found, which
## are also reported with `push_error`.
func rebuild() -> PackedStringArray:
	_entries.clear()
	_location_spawn_ids.clear()
	var errors := PackedStringArray()
	if not _index_content(errors):
		return errors
	errors.append_array(GameSettingsService.find_control_problems(GameSettingsService.game_controls()))
	_validate_audio_cues(errors)
	_validate_minigames(errors)
	_validate_locations(errors)
	_validate_content(errors)
	for message: String in errors:
		push_error("ContentDatabase: " + message)
	return errors

## Registers the entries of one kind and returns the id -> entry dictionary.
## `label` names the kind in error messages.
func register_entries(kind: StringName, resources: Array, label: String, errors: PackedStringArray) -> Dictionary:
	var target: Dictionary = {}
	_entries[kind] = target
	for resource: Resource in resources:
		if resource == null:
			continue
		var id := StringName(String(resource.get("id")))
		if id == &"":
			errors.append("%s resource has an empty id: %s" % [label, resource.resource_path])
			continue
		var key := String(id)
		if target.has(key):
			errors.append("duplicate %s id '%s'" % [label, key])
			continue
		target[key] = resource
	return target

## The entry of `kind` with `id`, or null.
func get_entry(kind: StringName, id: StringName) -> ContentEntry:
	return (_entries.get(kind, {}) as Dictionary).get(String(id)) as ContentEntry

func has_entry(kind: StringName, id: StringName) -> bool:
	return get_entry(kind, id) != null

## Every entry of `kind`, sorted by id.
func get_entries(kind: StringName) -> Array:
	return _sorted_values(_entries.get(kind, {}))

func get_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for kind: StringName in _entries:
		kinds.append(kind)
	return kinds

func get_location(id: StringName) -> WorldLocationData:
	return get_entry(KIND_LOCATION, id) as WorldLocationData

func get_all_locations() -> Array[WorldLocationData]:
	var result: Array[WorldLocationData] = []
	for value: Variant in get_entries(KIND_LOCATION):
		result.append(value as WorldLocationData)
	return result

func get_location_for_scene(scene_path: String) -> WorldLocationData:
	if scene_path.is_empty():
		return null
	for location: WorldLocationData in get_all_locations():
		if location != null and location.scene_path == scene_path:
			return location
	return null

func get_current_location(tree: SceneTree) -> WorldLocationData:
	if tree == null or tree.current_scene == null:
		return null
	return get_location_for_scene(tree.current_scene.scene_file_path)

func has_location_spawn(location_id: StringName, spawn_id: StringName) -> bool:
	if location_id == &"" or spawn_id == &"":
		return false
	var raw_counts: Variant = _location_spawn_ids.get(String(location_id), {})
	if not raw_counts is Dictionary:
		return false
	return int((raw_counts as Dictionary).get(String(spawn_id), 0)) == 1

func get_minigame(id: StringName) -> MiniGameDefinition:
	return get_entry(KIND_MINIGAME, id) as MiniGameDefinition

func get_audio_cue(id: StringName) -> AudioCueData:
	return get_entry(KIND_AUDIO_CUE, id) as AudioCueData

func get_all_audio_cues() -> Array[AudioCueData]:
	var result: Array[AudioCueData] = []
	for value: Variant in get_entries(KIND_AUDIO_CUE):
		result.append(value as AudioCueData)
	return result

## Overridden by the game: registers every kind with `register_entries()`,
## including `KIND_LOCATION`, `KIND_AUDIO_CUE` and `KIND_MINIGAME`. Returning false stops the
## rebuild before validation.
func _index_content(_errors: PackedStringArray) -> bool:
	return true

## Overridden by the game: checks references between its own kinds.
func _validate_content(_errors: PackedStringArray) -> void:
	pass

## Overridden by the game: checks the nodes of one location's scene that belong
## to its modules. `root` is a fresh instance freed after the call.
func _validate_location_scene(_location: WorldLocationData, _root: Node, _errors: PackedStringArray) -> void:
	pass

func _validate_audio_cues(errors: PackedStringArray) -> void:
	for raw: Variant in get_entries(KIND_AUDIO_CUE):
		var cue := raw as AudioCueData
		if cue == null:
			continue
		if not [AudioCueData.CueType.SFX, AudioCueData.CueType.MUSIC].has(cue.cue_type):
			errors.append("audio cue '%s' has invalid cue type %d" % [cue.id, cue.cue_type])
		if cue.pitch_min <= 0.0 or cue.pitch_max <= 0.0:
			errors.append("audio cue '%s' has non-positive pitch range" % cue.id)
		if cue.pitch_min > cue.pitch_max:
			errors.append("audio cue '%s' has inverted pitch range" % cue.id)

func _validate_minigames(errors: PackedStringArray) -> void:
	for raw: Variant in get_entries(KIND_MINIGAME):
		var minigame := raw as MiniGameDefinition
		if minigame == null:
			continue
		if minigame.scene == null:
			errors.append("minigame '%s' has no scene" % minigame.id)
			continue
		var root := minigame.scene.instantiate()
		if not root is MiniGame:
			errors.append("minigame '%s' scene root does not extend MiniGame" % minigame.id)
		if root != null:
			root.free()

func _validate_locations(errors: PackedStringArray) -> void:
	# First pass: load every scene once and record its spawn points, so portals
	# can be checked against any target location in the second pass.
	var scene_paths: Dictionary = {}
	var roots: Dictionary = {}
	for location: WorldLocationData in get_all_locations():
		if location == null:
			continue
		if location.scene_path.is_empty() or not ResourceLoader.exists(location.scene_path):
			errors.append("location '%s' references missing scene '%s'" % [location.id, location.scene_path])
			continue
		var packed := load(location.scene_path) as PackedScene
		if packed == null:
			errors.append("location '%s' scene '%s' is not a PackedScene" % [location.id, location.scene_path])
			continue
		if scene_paths.has(location.scene_path):
			errors.append("locations '%s' and '%s' share scene path '%s'" % [scene_paths[location.scene_path], location.id, location.scene_path])
		else:
			scene_paths[location.scene_path] = String(location.id)
		var root := packed.instantiate()
		if root == null:
			continue
		roots[String(location.id)] = root
		var spawn_counts: Dictionary = {}
		_collect_spawn_counts(root, spawn_counts)
		_location_spawn_ids[String(location.id)] = spawn_counts
	for location: WorldLocationData in get_all_locations():
		if location == null or not roots.has(String(location.id)):
			continue
		var root: Node = roots[String(location.id)]
		var spawn_counts: Dictionary = _location_spawn_ids[String(location.id)]
		var player_count := _count_group_nodes(root, &"player")
		if player_count != 1:
			errors.append("location '%s' scene must contain exactly one player node, found %d" % [location.id, player_count])
		_validate_location_scene(location, root, errors)
		for raw_spawn_id: Variant in spawn_counts.keys():
			var spawn_id := String(raw_spawn_id)
			if spawn_id.is_empty():
				errors.append("location '%s' scene has a spawn point with an empty id" % location.id)
			elif int(spawn_counts[raw_spawn_id]) > 1:
				errors.append("location '%s' scene has duplicate spawn id '%s'" % [location.id, spawn_id])
		if location.default_spawn_id == &"":
			errors.append("location '%s' has an empty default spawn id" % location.id)
		elif not spawn_counts.has(String(location.default_spawn_id)):
			errors.append("location '%s' default spawn '%s' is missing from scene '%s'" % [location.id, location.default_spawn_id, location.scene_path])
		if location.music_cue_id != &"":
			var music_cue := get_audio_cue(location.music_cue_id)
			if music_cue == null:
				errors.append("location '%s' references unknown music cue '%s'" % [location.id, location.music_cue_id])
			elif not music_cue.is_music():
				errors.append("location '%s' music cue '%s' is not MUSIC" % [location.id, location.music_cue_id])
		var portals: Array[ScenePortal] = []
		_collect_portals(root, portals)
		for portal: ScenePortal in portals:
			_validate_portal(location, portal, errors)
	for root: Node in roots.values():
		root.free()

func _validate_portal(source_location: WorldLocationData, portal: ScenePortal, errors: PackedStringArray) -> void:
	var portal_name := String(portal.name)
	if portal.target_location_id == &"":
		errors.append("location '%s' portal '%s' must use a stable target location id" % [source_location.id, portal_name])
		return
	var target_location := get_location(portal.target_location_id)
	if target_location == null:
		errors.append("location '%s' portal '%s' references unknown target location '%s'" % [source_location.id, portal_name, portal.target_location_id])
		return
	if not _location_spawn_ids.has(String(target_location.id)):
		errors.append("location '%s' portal '%s' target location '%s' has no valid PackedScene" % [source_location.id, portal_name, portal.target_location_id])
		return
	var resolved_spawn := portal.target_spawn_id if portal.target_spawn_id != &"" else target_location.default_spawn_id
	var target_spawns: Dictionary = _location_spawn_ids[String(target_location.id)]
	if resolved_spawn == &"" or not target_spawns.has(String(resolved_spawn)):
		errors.append("location '%s' portal '%s' target spawn '%s' is missing from location '%s'" % [source_location.id, portal_name, resolved_spawn, portal.target_location_id])

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

## Collects the dependency cycles of `graph` (node -> Array of neighbour nodes)
## as readable messages; `label` names the kind of node.
func collect_dependency_cycle_errors(graph: Dictionary, label: String) -> Array[String]:
	var messages: Array[String] = []
	var state: Dictionary = {}
	var stack: Array[String] = []
	var reported: Dictionary = {}
	var nodes: Array[String] = []
	for raw_node: Variant in graph.keys():
		nodes.append(String(raw_node))
	nodes.sort()
	for node: String in nodes:
		if int(state.get(node, 0)) == 0:
			_visit_dependency_node(node, graph, state, stack, reported, label, messages)
	return messages

func _visit_dependency_node(node: String, graph: Dictionary, state: Dictionary, stack: Array[String], reported: Dictionary, label: String, messages: Array[String]) -> void:
	state[node] = 1
	stack.append(node)
	var neighbors: Array[String] = []
	var raw_neighbors: Variant = graph.get(node, [])
	if raw_neighbors is Array:
		for raw_neighbor: Variant in raw_neighbors:
			neighbors.append(String(raw_neighbor))
	neighbors.sort()
	for neighbor: String in neighbors:
		# Missing references are reported separately by the normal reference
		# validator; they cannot participate in a cycle inside this graph.
		if not graph.has(neighbor):
			continue
		var neighbor_state := int(state.get(neighbor, 0))
		if neighbor_state == 0:
			_visit_dependency_node(neighbor, graph, state, stack, reported, label, messages)
		elif neighbor_state == 1:
			var start_index := stack.find(neighbor)
			if start_index < 0:
				continue
			var cycle_nodes: Array[String] = []
			for index in range(start_index, stack.size()):
				cycle_nodes.append(stack[index])
			var signature_nodes := cycle_nodes.duplicate()
			signature_nodes.sort()
			var signature := "|".join(PackedStringArray(signature_nodes))
			if reported.has(signature):
				continue
			reported[signature] = true
			var cycle_path := cycle_nodes.duplicate()
			cycle_path.append(neighbor)
			messages.append("%s dependency cycle: %s" % [label, " -> ".join(PackedStringArray(cycle_path))])
	stack.pop_back()
	state[node] = 2

func _sorted_values(source: Dictionary) -> Array:
	var keys: Array[String] = []
	for raw_key: Variant in source.keys():
		keys.append(String(raw_key))
	keys.sort()
	var result: Array = []
	for key: String in keys:
		result.append(source[key])
	return result
