class_name DepthTrack
extends RefCounted

## A way down that goes depth by depth, such as a mine's floors or a dungeon's
## depths: the depth the player is at and the deepest one they reached, kept in
## the world (`WorldState`, `<key>:depth` and `<key>:deepest`) so they save with
## it and a new game starts over. A track may end at `max_depth` and may let
## the player return to every `checkpoint_step`th depth they reached (an
## elevator's stops); each depth has its own random stream, so the same world
## lays out the same depth the same way.
##
## A service that owns a track (`MineState`) keeps it and passes its signals
## on as its own, which content follows as events.

## The player moved to another depth.
signal depth_changed(depth: int)
## The player went deeper than ever before in this world.
signal deepest_changed(depth: int)

## How deep a track without a bottom goes at most.
const DEPTH_LIMIT := 1000000
## How many depths `get_checkpoints()` lists at most.
const MAX_LISTED_CHECKPOINTS := 256

## The name of the track's values in the world and of its random streams.
var key: StringName
## The last depth, or 0 for a track without a bottom.
var max_depth: int
## Every how many depths a checkpoint comes, or 0 for none.
var checkpoint_step: int

func _init(track_key: StringName, bottom := 0, step := 0) -> void:
	key = track_key
	max_depth = maxi(bottom, 0)
	checkpoint_step = maxi(step, 0)

## The depth the player is at, from 1.
func get_depth() -> int:
	return _clamp(SaveValues.whole_number_or(WorldState.get_value(_depth_key(), 1), 1))

## The deepest depth reached in this world; 0 before the first.
func get_deepest() -> int:
	return mini(SaveValues.count(WorldState.get_value(_deepest_key(), 0)), _last_depth())

## Moves the player to `depth` (clamped to the track) and returns it. Going
## deeper than ever before raises the deepest depth first.
func set_depth(depth: int) -> int:
	var next := _clamp(depth)
	var previous := get_depth()
	WorldState.set_value(_depth_key(), next)
	if next > get_deepest():
		WorldState.set_value(_deepest_key(), next)
		deepest_changed.emit(next)
	if next != previous:
		depth_changed.emit(next)
	return next

## Moves the player one depth down, unless they are at the bottom.
func descend() -> int:
	return set_depth(get_depth() + 1)

## Whether the player is at the last depth of a track with a bottom.
func is_at_bottom() -> bool:
	return max_depth > 0 and get_depth() >= max_depth

## Whether `depth` is a checkpoint of the track (it need not be reached).
func is_checkpoint(depth: int) -> bool:
	return checkpoint_step > 0 and depth >= checkpoint_step and depth % checkpoint_step == 0 and _fits(depth)

## The depths the player can return to directly: the first, and every
## checkpoint down to the deepest reached; of a track gone very deep, the
## deepest `MAX_LISTED_CHECKPOINTS` - 1 checkpoints after the first.
func get_checkpoints() -> PackedInt32Array:
	var result := PackedInt32Array([1])
	var last := get_deepest_checkpoint()
	if last <= 1:
		return result
	var first := maxi(checkpoint_step, 2)
	var depth := maxi(last - (MAX_LISTED_CHECKPOINTS - 2) * checkpoint_step, first)
	while depth <= last:
		result.append(depth)
		depth += checkpoint_step
	return result

## Whether the player can return to `depth` directly (`get_checkpoints()`).
func can_return_to(depth: int) -> bool:
	return depth == 1 or (is_checkpoint(depth) and depth <= get_deepest())

## The deepest depth the player can return to directly.
func get_deepest_checkpoint() -> int:
	if checkpoint_step <= 0:
		return 1
	var deepest := get_deepest()
	return maxi(deepest - deepest % checkpoint_step, 1)

## The random stream of `depth` (`GameRandom.stream()`), `"<key>:<depth>"`;
## `salt` names another stream of the same depth (a run's, `"<key>:<depth>:<salt>"`).
func stream(depth: int, salt := "") -> GameRandomStream:
	var name := "%s:%d" % [key, depth]
	return GameRandom.stream(name if salt.is_empty() else "%s:%s" % [name, salt])

## The deepest depth of the track `track_key` that `snapshot`, a save, holds;
## 0 when it holds none.
static func read_saved_deepest(snapshot: Dictionary, track_key: StringName) -> int:
	return SaveValues.count(PersistentWorldState.read_saved(snapshot, StringName("%s:deepest" % track_key)))

func _clamp(depth: int) -> int:
	return clampi(depth, 1, _last_depth())

func _last_depth() -> int:
	return max_depth if max_depth > 0 else DEPTH_LIMIT

func _fits(depth: int) -> bool:
	return depth <= _last_depth()

func _depth_key() -> StringName:
	return StringName("%s:depth" % key)

func _deepest_key() -> StringName:
	return StringName("%s:deepest" % key)
