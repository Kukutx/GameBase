class_name NodePool
extends RefCounted

## Instances of one scene used again rather than made and freed each time:
## hit sparks, damage numbers, arrows. `take()` puts a kept instance (or a new
## one) under a parent; `give_back()` takes it out of the tree at the end of the
## frame and keeps it for a later `take()`, up to `capacity` instances, and
## frees the rest, so an instance may give itself back from its own signals
## and physics callbacks. An
## instance that must start over each time it is taken resets itself in a
## `reuse()` method of its own, which `take()` calls once it is in the tree.
## The pool frees what it keeps when it is cleared or freed itself.

## How many instances the pool keeps at most.
var capacity: int

var _scene: PackedScene
var _kept: Array[Node] = []

func _init(scene: PackedScene, keep := 16) -> void:
	_scene = scene
	capacity = maxi(keep, 0)

## An instance under `parent`: a kept one out of the tree, or a new one.
func take(parent: Node) -> Node:
	var node: Node = null
	for index: int in range(_kept.size() - 1, -1, -1):
		var kept := _kept[index]
		if not is_instance_valid(kept):
			_kept.remove_at(index)
		elif kept.get_parent() == null:
			# One given back this frame is still on its way out of the tree.
			node = kept
			_kept.remove_at(index)
			break
	if node == null:
		node = _scene.instantiate()
	parent.add_child(node)
	if node.has_method("reuse"):
		node.call("reuse")
	return node

## Keeps `node` for a later `take()` and takes it out of the tree at the end of
## the frame, or frees it then when the pool is full.
func give_back(node: Node) -> void:
	if not is_instance_valid(node) or _kept.has(node):
		return
	if _kept.size() >= capacity:
		node.queue_free()
		return
	_kept.append(node)
	if node.get_parent() != null:
		_put_away.call_deferred(node)

## How many instances the pool keeps now.
func get_kept_count() -> int:
	return _kept.size()

## Frees every instance the pool keeps (at the end of the frame for one still
## in the tree).
func clear() -> void:
	for node: Node in _kept:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.queue_free()
			else:
				node.free()
	_kept.clear()

func _put_away(node: Node) -> void:
	# Freed meanwhile, or the pool cleared: nothing to keep.
	if not is_instance_valid(node) or not _kept.has(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)

func _notification(what: int) -> void:
	# A pool being freed has no `self` to call its methods on.
	if what == NOTIFICATION_PREDELETE:
		for node: Node in _kept:
			if is_instance_valid(node):
				if node.get_parent() != null:
					node.queue_free()
				else:
					node.free()
