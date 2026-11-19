extends GutTest

func test_a_stored_reward_reads_only_whole_counts() -> void:
	var stored := {"items": {"fixture_seeds": 3.0, "fixture_twig": 2.5}, "money": 1.0e18}
	var reward := DeferredRewardSnapshot.ensure(stored, {}, 0)
	assert_eq(reward["items"], {"fixture_seeds": 3}, "JSON gives a count back as a float; a fraction is none")
	assert_eq(DeferredRewardSnapshot.get_money(reward), 0, "nor money past what JSON keeps exactly")
	assert_eq(DeferredRewardSnapshot.get_money({"money": 40.0}), 40)
