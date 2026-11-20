extends GutTest

## Enemy tiers (`EnemyTier`): the ordinary ones a depth reaches, the deepest
## of them, and the guardians that hold only the depths they guard.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

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

func test_a_tier_with_a_last_depth_stops_there() -> void:
	var king := _tier(&"king", 25, 25)
	king.maximum_depth = 50
	var tiers := [_tier(&"slime", 1), king, _tier(&"monarch", 75, 25)] as Array[EnemyTier]
	assert_eq(EnemyTier.guardians(tiers, 25), [&"king"] as Array[StringName])
	assert_eq(EnemyTier.guardians(tiers, 50), [&"king"] as Array[StringName], "its last depth is its own")
	assert_eq(EnemyTier.guardians(tiers, 75), [&"monarch"] as Array[StringName], "a stronger guardian takes over below")
	assert_eq(EnemyTier.guardians(tiers, 100), [&"monarch"] as Array[StringName])
	var shallow := _tier(&"bat", 3)
	shallow.maximum_depth = 9
	var ordinary := [_tier(&"slime", 1), shallow] as Array[EnemyTier]
	assert_eq(EnemyTier.reached(ordinary, 9), [&"slime", &"bat"] as Array[StringName])
	assert_eq(EnemyTier.reached(ordinary, 10), [&"slime"] as Array[StringName], "an ordinary tier stops too")
	assert_eq(EnemyTier.deepest(ordinary, 10), &"slime")

func test_a_tier_that_ends_before_it_starts_is_a_problem() -> void:
	var enemy := EnemyData.new()
	enemy.id = &"bat"
	var registry := ContentFixture.use(self, [enemy])
	var backwards := _tier(&"bat", 10)
	backwards.maximum_depth = 4
	assert_eq(EnemyTier.find_problems([_tier(&"bat", 1), backwards] as Array[EnemyTier], registry), PackedStringArray([
		"enemy tier 'bat' ends at depth 4, before it starts at 10",
	]))

func _tiers() -> Array[EnemyTier]:
	return [_tier(&"slime", 1), _tier(&"bat", 3), _tier(&"warden", 5, 5)] as Array[EnemyTier]

func _tier(enemy_id: StringName, minimum_depth: int, guardian_every := 0) -> EnemyTier:
	var tier := EnemyTier.new()
	tier.enemy_id = enemy_id
	tier.minimum_depth = minimum_depth
	tier.guardian_every = guardian_every
	return tier
