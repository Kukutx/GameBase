extends GutTest

## Enemy tiers (`EnemyTier`): the ordinary ones a depth reaches, the deepest
## of them, and the guardians that hold only the depths they guard.

func test_a_depth_reaches_the_ordinary_tiers_from_their_minimum_depth() -> void:
	var tiers := _tiers()
	assert_eq(EnemyTier.reached(tiers, 1), [&"slime"] as Array[StringName])
	assert_eq(EnemyTier.reached(tiers, 5), [&"slime", &"bat"] as Array[StringName], "a guardian is no ordinary enemy")
	assert_eq(EnemyTier.deepest(tiers, 9), &"bat", "nor the deepest")

func test_a_guardian_holds_every_depth_it_guards_and_no_other() -> void:
	var tiers := _tiers()
	for depth: int in [1, 4, 6, 9, 11]:
		assert_eq(EnemyTier.guardians(tiers, depth), [] as Array[StringName], "depth %d" % depth)
	for depth: int in [5, 10, 15]:
		assert_eq(EnemyTier.guardians(tiers, depth), [&"warden"] as Array[StringName], "depth %d" % depth)
	var odd := _tier(&"wyrm", 3, 4)
	assert_true(odd.guards(3) and odd.guards(7) and odd.guards(11), "from its minimum depth on, every so many")
	assert_false(odd.guards(4) or odd.guards(8))
	assert_false(_tier(&"slime", 1).guards(1), "an ordinary tier guards nothing")

func _tiers() -> Array[EnemyTier]:
	return [_tier(&"slime", 1), _tier(&"bat", 3), _tier(&"warden", 5, 5)] as Array[EnemyTier]

func _tier(enemy_id: StringName, minimum_depth: int, guardian_every := 0) -> EnemyTier:
	var tier := EnemyTier.new()
	tier.enemy_id = enemy_id
	tier.minimum_depth = minimum_depth
	tier.guardian_every = guardian_every
	return tier
