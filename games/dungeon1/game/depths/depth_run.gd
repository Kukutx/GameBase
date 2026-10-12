class_name DepthRunService
extends Node

## Ember Depths' runs into the depths: the depth the player has reached, the
## deepest this world has seen and how many runs it has started. They live in
## the world (`WorldState`), so they save with it. Every depth reached also
## raises the profile's deepest depth, which outlives every save, and triggers
## follow `depth_reached` (Ember Depths' achievements).

signal depth_reached(depth: int)

const DEPTH_KEY := &"depths:depth"
const DEEPEST_KEY := &"depths:deepest"
const RUN_KEY := &"depths:run"
## Profile flag: the deepest depth of any run in any save.
const PROFILE_DEEPEST := &"deepest_depth"

## The depth of the run, from 1.
func get_depth() -> int:
	return maxi(WorldState.get_int(DEPTH_KEY), 1)

## The deepest depth this world reached (0 before the first run).
func get_deepest() -> int:
	return maxi(WorldState.get_int(DEEPEST_KEY), 0)

## How many runs this world started.
func get_run() -> int:
	return maxi(WorldState.get_int(RUN_KEY), 0)

## Starts a new run at the first depth.
func start_run() -> void:
	WorldState.add_int(RUN_KEY, 1)
	_reach(1)

## Goes one depth further down.
func descend() -> void:
	_reach(get_depth() + 1)

## A random stream of the current run and depth (`GameRandom.stream()`): the
## same world, run and depth always lay out the same floor.
func floor_stream() -> GameRandomStream:
	return GameRandom.stream("depths:%d:%d" % [get_run(), get_depth()])

## Why the game cannot be saved now (a save blocker): a floor is laid out
## fresh each time it is entered, so the player saves at camp.
func get_save_block_reason() -> String:
	return tr("Return to camp to save") if get_tree().current_scene is DepthFloor else ""

func _reach(depth: int) -> void:
	WorldState.set_value(DEPTH_KEY, depth)
	if depth > get_deepest():
		WorldState.set_value(DEEPEST_KEY, depth)
	if depth > GameProfile.get_int(PROFILE_DEEPEST):
		GameProfile.set_flag(PROFILE_DEEPEST, depth)
	depth_reached.emit(depth)
