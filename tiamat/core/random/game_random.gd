class_name GameRandomService
extends Node

## The world's randomness: one seed per game, and from it a separate stream for
## each thing that rolls dice, named by a key (`"weather:12"`,
## `"fish:3:0:river"`).
##
## The same seed and key always give the same numbers, on every platform and
## engine version (`GameRandomStream` is the project's own algorithm), so
## loading a save replays the day's weather, catches and mine floors instead of
## rolling them again, and a test pins an outcome by its seed.
## Gameplay randomness goes through here; cosmetic jitter, such as a sound's
## pitch, may use the global generator.

signal seed_changed(world_seed: int)

## The current world's seed. Change it with `set_seed()`.
var world_seed := 0

## Makes `value` the world's seed; every stream follows it.
func set_seed(value: int) -> void:
	world_seed = value
	seed_changed.emit(world_seed)

## A new stream for `key` in this world, at the start of its sequence: seeded
## by the SHA-256 of the world seed and the key ("<seed>:<key>").
func stream(key: String) -> GameRandomStream:
	return GameRandomStream.new(("%d:%s" % [world_seed, key]).sha256_buffer())

## Seeds a new game: the game's own `GameDefinition.world_seed`, or a fresh one
## when the game fixes none (0).
func reset_new_game() -> void:
	var fixed := GameDefinition.current().world_seed
	set_seed(fixed if fixed != 0 else fresh_seed())

## A seed no earlier game used, within 32 bits so it survives JSON.
static func fresh_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi()) + 1

func to_save_data() -> Dictionary:
	return {"world_seed": world_seed}

func load_save_data(data: Dictionary) -> void:
	var raw: Variant = data.get("world_seed", 0)
	set_seed(SaveValues.whole_number_or(raw, 0))
