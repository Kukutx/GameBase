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
	for roll: int in range(5):
		assert_eq(first.randi(), second.randi(), "roll %d" % roll)
	assert_ne(GameRandom.seed_for("fixture:dice"), GameRandom.seed_for("fixture:coin"), "each key has its own stream")

func test_stream_seeds_do_not_depend_on_the_engine_or_platform() -> void:
	# SHA-256 of "<seed>:<key>", its first eight bytes as a little-endian int.
	GameRandom.set_seed(1)
	assert_eq(GameRandom.seed_for("weather:1"), 4041423546182936500)
	GameRandom.set_seed(93017)
	assert_eq(GameRandom.seed_for("fish:1:0:river"), -5944058399785437185)

func test_changing_the_seed_changes_the_streams_and_says_so() -> void:
	GameRandom.set_seed(1)
	var before := GameRandom.seed_for("fixture:dice")
	watch_signals(GameRandom)
	GameRandom.set_seed(2)
	assert_signal_emitted_with_parameters(GameRandom, "seed_changed", [2])
	assert_ne(GameRandom.seed_for("fixture:dice"), before)

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
