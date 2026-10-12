extends GutTest

## Nodes found by an id (`NodeRegistry`): one node per id, gone from the
## registry when it leaves the tree.

func after_each() -> void:
	for id: StringName in NodeRegistry.get_ids("fixture:"):
		NodeRegistry.unregister(NodeRegistry.find(id), id)

func test_a_node_is_found_by_its_ids_until_it_leaves_the_tree() -> void:
	var boss := Node.new()
	assert_false(NodeRegistry.register(boss, &"fixture:boss"), "not in the tree yet")
	add_child_autofree(boss)
	assert_true(NodeRegistry.register(boss, &"fixture:boss"))
	assert_true(NodeRegistry.register(boss, &"fixture:boss"), "it holds the id already")
	assert_true(NodeRegistry.register(boss, &"fixture:arena_focus"), "one node may hold several ids")
	assert_eq(NodeRegistry.find(&"fixture:boss"), boss)
	assert_eq(NodeRegistry.get_ids("fixture:"), [&"fixture:arena_focus", &"fixture:boss"] as Array[StringName])
	remove_child(boss)
	assert_null(NodeRegistry.find(&"fixture:boss"))
	assert_true(NodeRegistry.get_ids("fixture:").is_empty())
	add_child(boss)
	assert_true(NodeRegistry.register(boss, &"fixture:boss"), "back in the tree, it registers again")
	assert_eq(NodeRegistry.find(&"fixture:boss"), boss)

func test_one_node_holds_an_id_at_a_time() -> void:
	var door := add_child_autofree(Node.new()) as Node
	var other := add_child_autofree(Node.new()) as Node
	assert_true(NodeRegistry.register(door, &"fixture:door"))
	assert_false(NodeRegistry.register(other, &"fixture:door"))
	assert_push_warning("'fixture:door' is held by")
	NodeRegistry.unregister(other, &"fixture:door")
	assert_eq(NodeRegistry.find(&"fixture:door"), door, "only its holder lets an id go")
	NodeRegistry.unregister(door, &"fixture:door")
	assert_null(NodeRegistry.find(&"fixture:door"))
	assert_true(NodeRegistry.register(other, &"fixture:door"))
	remove_child(door)
	assert_eq(NodeRegistry.find(&"fixture:door"), other, "a node that let the id go takes nothing with it")
