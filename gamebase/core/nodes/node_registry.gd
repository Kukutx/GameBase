class_name NodeRegistry
extends RefCounted

## Nodes found by an id anywhere in the scene tree: a boss a cutscene speaks
## to, a door a switch opens, a camera a trigger moves. A node registers
## itself under an id (`register()`, usually in its `_ready()`) and leaves the
## registry when it leaves the tree, so a scene change never leaves a stale
## entry. One node holds an id at a time.

# id -> {"node": Node, "leave": the Callable connected to its tree_exiting}
static var _entries: Dictionary[StringName, Dictionary] = {}

## Registers `node` under `id` until it leaves the tree. False when another
## node holds the id, or `node` is not in the tree.
static func register(node: Node, id: StringName) -> bool:
	if node == null or id == &"" or not node.is_inside_tree():
		return false
	var holder := find(id)
	if holder == node:
		return true
	if holder != null:
		push_warning("NodeRegistry: '%s' is held by %s" % [id, holder.get_path()])
		return false
	# A callable of its own per entry: bound callables of one method compare
	# equal whatever they bind, so a node's second id would not connect.
	var leave := func() -> void: _erase(id, node)
	node.tree_exiting.connect(leave, CONNECT_ONE_SHOT)
	_entries[id] = {"node": node, "leave": leave}
	return true

## The node registered under `id`, or null.
static func find(id: StringName) -> Node:
	var entry: Dictionary = _entries.get(id, {})
	var node: Variant = entry.get("node")
	return node as Node if is_instance_valid(node) else null

## The ids registered now that begin with `prefix`, sorted.
static func get_ids(prefix := "") -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _entries:
		if String(id).begins_with(prefix) and find(id) != null:
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids

## Takes `node` out of the registry under `id` while it stays in the tree.
static func unregister(node: Node, id: StringName) -> void:
	var entry: Dictionary = _entries.get(id, {})
	if entry.get("node") != node:
		return
	var leave: Callable = entry["leave"]
	if node.tree_exiting.is_connected(leave):
		node.tree_exiting.disconnect(leave)
	_entries.erase(id)

static func _erase(id: StringName, node: Node) -> void:
	var entry: Dictionary = _entries.get(id, {})
	if entry.get("node") == node:
		_entries.erase(id)
