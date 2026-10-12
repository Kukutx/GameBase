extends GutTest

## A way down depth by depth (`DepthTrack`): the depth, the deepest one, the
## bottom, the checkpoints and each depth's random stream.

var _world: Dictionary

func before_each() -> void:
	_world = WorldState.to_save_data()
	WorldState.clear()

func after_each() -> void:
	WorldState.load_save_data(_world)

func test_it_goes_down_and_keeps_the_deepest_depth_in_the_world() -> void:
	var track := DepthTrack.new(&"fixture_cave")
	watch_signals(track)
	assert_eq(track.get_depth(), 1)
	assert_eq(track.get_deepest(), 0, "nothing is reached before the first depth")
	assert_eq(track.set_depth(1), 1)
	assert_signal_emitted_with_parameters(track, "deepest_changed", [1])
	assert_signal_not_emitted(track, "depth_changed", "the player was at the first depth already")
	assert_eq(track.descend(), 2)
	assert_eq(track.descend(), 3)
	assert_signal_emitted_with_parameters(track, "depth_changed", [3])
	assert_eq(track.set_depth(1), 1)
	assert_eq(track.get_deepest(), 3, "going back up keeps the deepest depth")
	assert_eq(WorldState.get_int(&"fixture_cave:depth"), 1)
	assert_eq(WorldState.get_int(&"fixture_cave:deepest"), 3)
	assert_eq(DepthTrack.read_saved_deepest({"world": WorldState.to_save_data()}, &"fixture_cave"), 3)
	assert_eq(track.set_depth(-4), 1, "there is nothing above the first depth")
	assert_false(track.is_at_bottom(), "a track without a bottom has none")

func test_a_track_with_a_bottom_and_checkpoints() -> void:
	var track := DepthTrack.new(&"fixture_mine", 12, 5)
	assert_eq(track.set_depth(40), 12)
	assert_true(track.is_at_bottom())
	assert_eq(track.descend(), 12, "the bottom leads nowhere deeper")
	assert_eq(Array(track.get_checkpoints()), [1, 5, 10])
	assert_eq(track.get_deepest_checkpoint(), 10)
	assert_true(track.can_return_to(10))
	assert_false(track.can_return_to(12), "the bottom is no checkpoint")
	assert_false(track.is_checkpoint(15), "past the bottom")
	WorldState.set_value(&"fixture_mine:deepest", 999)
	assert_eq(track.get_deepest(), 12, "a deepest depth past the bottom reads as the bottom")

func test_a_malformed_depth_reads_as_the_first() -> void:
	var track := DepthTrack.new(&"fixture_cave", 0, 5)
	WorldState.set_value(&"fixture_cave:depth", {"bad": true})
	WorldState.set_value(&"fixture_cave:deepest", [7])
	assert_eq(track.get_depth(), 1)
	assert_eq(track.get_deepest(), 0)
	assert_eq(Array(track.get_checkpoints()), [1])

func test_each_depth_has_a_stream_of_its_own() -> void:
	var track := DepthTrack.new(&"fixture_cave")
	assert_eq(track.stream(3).randi(), track.stream(3).randi(), "the same depth rolls the same")
	assert_ne(track.stream(3).randi(), track.stream(4).randi())
	assert_ne(track.stream(3).randi(), track.stream(3, "run2").randi(), "a salt names another stream")
	assert_eq(track.stream(3, "run2").randi(), GameRandom.stream("fixture_cave:3:run2").randi())

func test_every_depth_is_a_checkpoint_with_a_step_of_one() -> void:
	var track := DepthTrack.new(&"fixture_cave", 0, 1)
	track.set_depth(4)
	assert_eq(Array(track.get_checkpoints()), [1, 2, 3, 4])
	assert_eq(track.get_deepest_checkpoint(), 4)

func test_a_track_gone_very_deep_lists_its_deepest_checkpoints() -> void:
	var track := DepthTrack.new(&"fixture_cave", 0, 5)
	WorldState.set_value(&"fixture_cave:deepest", 9223372036854775807)
	assert_eq(track.get_deepest(), DepthTrack.DEPTH_LIMIT, "no deeper than the limit")
	var checkpoints := track.get_checkpoints()
	assert_eq(checkpoints.size(), DepthTrack.MAX_LISTED_CHECKPOINTS)
	assert_eq(checkpoints[0], 1)
	assert_eq(checkpoints[checkpoints.size() - 1], DepthTrack.DEPTH_LIMIT)
	assert_eq(checkpoints[1], DepthTrack.DEPTH_LIMIT - (DepthTrack.MAX_LISTED_CHECKPOINTS - 2) * 5)
	assert_eq(track.set_depth(DepthTrack.DEPTH_LIMIT + 3), DepthTrack.DEPTH_LIMIT)
