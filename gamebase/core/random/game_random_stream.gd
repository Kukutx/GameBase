class_name GameRandomStream
extends RefCounted

## A sequence of random numbers that is the project's own: xoshiro128**
## (Blackman and Vigna) over four 32-bit words. The engine's
## `RandomNumberGenerator` may change its algorithm between engine versions;
## this one gives the same numbers from the same seed on every version and
## platform, so a saved world keeps its weather, catches and mine floors.
## Get one from `GameRandom.stream()`.

const _MASK := 0xFFFFFFFF
const _SPAN := 0x100000000

var _s0 := 0
var _s1 := 0
var _s2 := 0
var _s3 := 0

## A stream at the start of the sequence the first sixteen bytes of
## `seed_bytes` name (four little-endian 32-bit words).
func _init(seed_bytes: PackedByteArray) -> void:
	_s0 = seed_bytes.decode_u32(0)
	_s1 = seed_bytes.decode_u32(4)
	_s2 = seed_bytes.decode_u32(8)
	_s3 = seed_bytes.decode_u32(12)
	if _s0 == 0 and _s1 == 0 and _s2 == 0 and _s3 == 0:
		_s0 = 1 # An all-zero state would only ever give zeros.

## The next 32 random bits: 0 to 4294967295.
func randi() -> int:
	return _next()

## A float from 0 up to, but not including, 1.
func randf() -> float:
	return _next_float()

## A float from `from` up to, but not including, `to`.
func randf_range(from: float, to: float) -> float:
	return from + (to - from) * _next_float()

## An integer from `from` to `to`, both included, each equally likely. The
## range spans at most 2^32 values.
func randi_range(from: int, to: int) -> int:
	var low := mini(from, to)
	var span := maxi(from, to) - low + 1
	if span <= 1:
		return low
	# Drawing again past the last whole multiple of the span keeps the values even.
	var limit := _SPAN - _SPAN % span
	var value := _next()
	while value >= limit:
		value = _next()
	return low + value % span

# Inside this class a bare `randi()` or `randf()` is the engine's global
# generator, so the methods above draw through these.
func _next() -> int:
	var result := (_rotl((_s1 * 5) & _MASK, 7) * 9) & _MASK
	var shifted := (_s1 << 9) & _MASK
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= shifted
	_s3 = _rotl(_s3, 11)
	return result

func _next_float() -> float:
	return float(_next()) / _SPAN

static func _rotl(value: int, bits: int) -> int:
	return ((value << bits) | (value >> (32 - bits))) & _MASK
