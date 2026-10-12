extends GutTest

## Instances used again (`NodePool`): what is given back is kept for the next
## take, up to the capacity, and freed with the pool.

const SPARK_SCRIPT := preload("res://gamebase/core/test/fixtures/pooled_spark.gd")

func test_it_keeps_what_is_given_back_for_the_next_take() -> void:
	var pool := NodePool.new(_spark_scene(), 2)
	var parent := add_child_autofree(Node.new()) as Node
	var first := pool.take(parent)
	assert_eq(first.get_parent(), parent)
	assert_eq(int(first.get("takes")), 1, "it starts over once it is in the tree")
	pool.give_back(first)
	assert_eq(first.get_parent(), parent, "it leaves the tree at the end of the frame")
	pool.give_back(first)
	assert_eq(pool.get_kept_count(), 1, "an instance is kept once")
	var meanwhile := pool.take(parent)
	assert_ne(meanwhile, first, "one on its way out is not taken again yet")
	meanwhile.free()
	await get_tree().process_frame
	assert_null(first.get_parent())
	assert_eq(pool.take(parent), first, "the kept instance")
	assert_eq(int(first.get("takes")), 2)
	assert_eq(pool.get_kept_count(), 0)

	var taken: Array[Node] = [first, pool.take(parent), pool.take(parent)]
	for node: Node in taken:
		pool.give_back(node)
	assert_eq(pool.get_kept_count(), 2)
	await get_tree().process_frame
	assert_false(is_instance_valid(taken[2]), "past the capacity it is freed")
	pool.clear()
	assert_eq(pool.get_kept_count(), 0)
	assert_false(is_instance_valid(first))

func test_a_freed_pool_frees_what_it_keeps() -> void:
	var pool := NodePool.new(_spark_scene())
	var spark := pool.take(self)
	pool.give_back(spark)
	pool = null
	await get_tree().process_frame
	assert_false(is_instance_valid(spark))

func test_an_instance_gives_itself_back_from_its_own_signal() -> void:
	var parent := add_child_autofree(Node.new()) as Node
	for keep: int in [1, 0]:
		var pool := NodePool.new(_spark_scene(), keep)
		var spark := pool.take(parent)
		spark.renamed.connect(pool.give_back.bind(spark))
		# Kept or, past the capacity, freed: either waits for the signal to end.
		spark.name = "Spent"
		await get_tree().process_frame
		if keep > 0:
			assert_null(spark.get_parent())
			pool.clear()
		assert_false(is_instance_valid(spark))

func _spark_scene() -> PackedScene:
	var root := Node2D.new()
	root.set_script(SPARK_SCRIPT)
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
