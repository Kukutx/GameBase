extends GutTest

## Farm1's rocks open up with the mine depth of their metal tier, which is what
## its mining contracts offer at each depth. The contracts themselves are
## tested with the progression module.

func test_mining_nodes_unlock_at_the_mine_depth_of_their_tier() -> void:
	var expected_floors := {
		&"stone_rock": 1,
		&"copper_rock": 1,
		&"iron_rock": 6,
		&"gold_rock": 20,
		&"iridium_rock": 60,
	}
	for raw_id: Variant in expected_floors.keys():
		var node := MiningNodeData.find(StringName(String(raw_id)))
		assert_not_null(node)
		if node != null:
			assert_eq(node.minimum_mine_floor, int(expected_floors[raw_id]))
