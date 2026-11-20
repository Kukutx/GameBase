class_name DepthRunService
extends Node

## Ember Depths' runs into the depths: each a run of the roguelite module
## (`RunState`) down a track without a bottom (`DepthTrack`, `depths:depth`
## and `depths:deepest` in the world), so the depth the player has reached and
## the deepest this world has seen save with it. The run's tally `depth`
## (`RunTallyData`) keeps the depth it reached for its report and raises the
## profile's deepest depth, which outlives every save, and triggers follow
## `depth_reached` (Ember Depths' achievements). Every
## `SHORTCUT_STEP`th depth the world reached is a shortcut a new run may start
## at (`get_shortcuts()`), which the way down offers.

signal depth_reached(depth: int)

const TRACK_KEY := &"depths"
## Profile flag: the deepest depth of any run in any save, the best of the
## run tally `DEPTH_TALLY`.
const PROFILE_DEEPEST := &"deepest_depth"
## The run's tally of the depth it reached.
const DEPTH_TALLY := &"depth"
## Every how many depths a shortcut comes.
const SHORTCUT_STEP := 5

## The depths.
var track := DepthTrack.new(TRACK_KEY, 0, SHORTCUT_STEP)

## The depth of the run, from 1.
func get_depth() -> int:
	return track.get_depth()

## The deepest depth this world reached (0 before the first run).
func get_deepest() -> int:
	return track.get_deepest()

## What a save's slot shows of the depths: the deepest depth its world
## reached, or nothing before the first run (`SaveManager.register_slot_detail`).
func describe_save(snapshot: Dictionary) -> String:
	var deepest := DepthTrack.read_saved_deepest(snapshot, TRACK_KEY)
	return tr("Deepest %d") % deepest if deepest > 0 else ""

## How many runs this world started.
func get_run() -> int:
	return RunState.get_run()

## The depths a new run may start at: the first, and every `SHORTCUT_STEP`th
## depth this world reached.
func get_shortcuts() -> PackedInt32Array:
	return track.get_checkpoints()

## Starts a new run at `depth`, the first or a shortcut (`get_shortcuts()`);
## at the first one for any other. A run that starts at a shortcut does not
## reach it again: `depth_reached` tells of the first depth and of each the
## player goes down to.
func start_run(depth := 1) -> void:
	RunState.start_run()
	if depth > 1 and track.can_return_to(depth):
		track.set_depth(depth)
		RunState.raise_tally(DEPTH_TALLY, depth)
	else:
		_reach(1)

## Goes one depth further down; false when no run goes on (the player is on a
## floor because the way home failed).
func descend() -> bool:
	if not RunState.is_active():
		return false
	_reach(get_depth() + 1)
	return true

## Ends the run with the player back at camp with what they found.
func return_to_camp() -> void:
	RunState.end_run(RunService.OUTCOME_RETURNED)

## Why the game cannot be saved now (a save blocker): the player is on a depth
## floor, with a run or without one (the way home failed).
func get_save_block_reason() -> String:
	return tr("Return to camp to save") if get_tree().current_scene is DepthFloor else ""

## A random stream of the current run and depth (`DepthTrack.stream()`): the
## same world, run and depth always lay out the same floor.
func floor_stream() -> GameRandomStream:
	return track.stream(get_depth(), "run%d" % get_run())

func _reach(depth: int) -> void:
	track.set_depth(depth)
	RunState.raise_tally(DEPTH_TALLY, depth)
	depth_reached.emit(depth)
