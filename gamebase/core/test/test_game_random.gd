extends GutTest

## The world's seeded randomness (`GameRandomService`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _seed: int

func before_each() -> void:
	_seed = GameRandom.world_seed

func after_each() -> void:
	GameRandom.set_seed(_seed)

func test_a_seed_and_key_always_give_the_same_numbers() -> void:
	GameRandom.set_seed(1)
	var first := GameRandom.stream("fixture:dice")
	var second := GameRandom.stream("fixture:dice")
	var other := GameRandom.stream("fixture:coin")
	var first_rolls: Array[int] = []
	var other_rolls: Array[int] = []
	for roll: int in range(5):
		first_rolls.append(first.randi())
		assert_eq(second.randi(), first_rolls[roll], "roll %d" % roll)
		other_rolls.append(other.randi())
	assert_ne(other_rolls, first_rolls, "each key has its own stream")

func test_streams_do_not_depend_on_the_engine_or_platform() -> void:
	# xoshiro128** seeded by the SHA-256 of "<seed>:<key>"; any other numbers
	# would change every saved world's weather, catches and mine floors.
	GameRandom.set_seed(1)
	assert_eq(_rolls(GameRandom.stream("weather:1"), 4), [4017571052, 471733944, 644240611, 2742219543])
	GameRandom.set_seed(93017)
	assert_eq(_rolls(GameRandom.stream("fish:1:0:river"), 4), [4150751673, 2443695451, 1643198427, 1069341355])

func test_the_generator_is_xoshiro128_starstar() -> void:
	# The reference sequence of xoshiro128** from the state 1, 2, 3, 4.
	var stream := GameRandomStream.new(PackedByteArray([1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4, 0, 0, 0]))
	assert_eq(_rolls(stream, 6), [11520, 0, 5927040, 70819200, 2031721883, 1637235492])

func test_ranges_stay_inside_their_bounds() -> void:
	GameRandom.set_seed(7)
	var stream := GameRandom.stream("fixture:ranges")
	var seen := {}
	for roll: int in range(400):
		var value := stream.randi_range(3, 6)
		assert_between(value, 3, 6)
		seen[value] = true
		var fraction := stream.randf()
		assert_true(fraction >= 0.0 and fraction < 1.0, "randf %f is in [0, 1)" % fraction)
		var spot := stream.randf_range(-2.0, 2.0)
		assert_true(spot >= -2.0 and spot < 2.0, "randf_range %f is in [-2, 2)" % spot)
	assert_eq(seen.size(), 4, "every value in the range comes up")
	assert_eq(stream.randi_range(5, 5), 5)
	assert_between(stream.randi_range(9, 2), 2, 9)

func test_a_weighted_pick_follows_the_weights_and_never_takes_a_zero() -> void:
	GameRandom.set_seed(1)
	var stream := GameRandom.stream("fixture:weights")
	var counts := [0, 0, 0, 0]
	for _roll: int in range(4000):
		counts[stream.pick_weighted(PackedFloat64Array([1.0, 0.0, 3.0, -2.0]))] += 1
	assert_eq(counts[1] + counts[3], 0, "a weight of 0 or less is never picked")
	assert_almost_eq(float(counts[2]) / counts[0], 3.0, 0.4, "three times the weight, about three times as often")
	assert_eq(stream.pick_weighted(PackedFloat64Array()), -1)
	assert_eq(stream.pick_weighted(PackedFloat64Array([0.0, -1.0])), -1, "nothing to pick")
	assert_eq(stream.pick_weighted(PackedFloat64Array([0.0, 2.0])), 1)
	assert_null(stream.pick([]))
	var picked := {}
	for _roll: int in range(60):
		picked[stream.pick([&"a", &"b", &"c"])] = true
	assert_eq(picked.size(), 3, "each of a list comes up")

func test_scattered_points_keep_their_spacing_inside_their_area() -> void:
	GameRandom.set_seed(1)
	var area := Rect2(-100, -50, 200, 100)
	var taken := PackedVector2Array([Vector2.ZERO])
	var keep_right := func(point: Vector2) -> bool: return point.x > -60.0
	var points := GameRandom.stream("fixture:scatter").scatter(area, 6, 30.0, taken, Vector2(8, 8), keep_right)
	assert_eq(points, GameRandom.stream("fixture:scatter").scatter(area, 6, 30.0, taken, Vector2(8, 8), keep_right), "the same stream scatters the same")
	assert_eq(points.size(), 6)
	var near := taken.duplicate()
	for point: Vector2 in points:
		assert_true(area.grow(4.0).has_point(point), "%s is in the area" % point)
		assert_eq(point, point.snapped(Vector2(8, 8)))
		assert_gt(point.x, -60.0, "%s is one `accept` takes" % point)
		for other: Vector2 in near:
			assert_gte(point.distance_to(other), 30.0, "%s keeps clear of %s" % [point, other])
		near.append(point)
	var crowded := GameRandom.stream("fixture:crowd").scatter(Rect2(0, 0, 10, 10), 4, 100.0)
	assert_eq(crowded.size(), 4, "a crowded area still gets every point")
	assert_eq(GameRandom.stream("fixture:none").scatter(area, 0, 10.0), PackedVector2Array())

func test_changing_the_seed_changes_the_streams_and_says_so() -> void:
	GameRandom.set_seed(1)
	var before := _rolls(GameRandom.stream("fixture:dice"), 3)
	watch_signals(GameRandom)
	GameRandom.set_seed(2)
	assert_signal_emitted_with_parameters(GameRandom, "seed_changed", [2])
	assert_ne(_rolls(GameRandom.stream("fixture:dice"), 3), before)

func test_the_seed_survives_a_save() -> void:
	GameRandom.set_seed(424242)
	var saved := JSON.parse_string(JSON.stringify(GameRandom.to_save_data())) as Dictionary
	GameRandom.set_seed(7)
	GameRandom.load_save_data(saved)
	assert_eq(GameRandom.world_seed, 424242)
	GameRandom.load_save_data({"world_seed": "broken"})
	assert_eq(GameRandom.world_seed, 0)

func test_a_new_game_takes_the_games_seed_or_a_fresh_one() -> void:
	var fixed := GameDefinition.new()
	fixed.world_seed = 31337
	ContentFixture.with_definition(fixed, GameRandom.reset_new_game)
	assert_eq(GameRandom.world_seed, 31337)
	var unfixed := GameDefinition.new()
	ContentFixture.with_definition(unfixed, GameRandom.reset_new_game)
	assert_ne(GameRandom.world_seed, 0)
	assert_lt(GameRandom.world_seed, 1 << 33, "a fresh seed stays exact in JSON")

func _rolls(stream: GameRandomStream, count: int) -> Array[int]:
	var rolls: Array[int] = []
	for _roll: int in range(count):
		rolls.append(stream.randi())
	return rolls
