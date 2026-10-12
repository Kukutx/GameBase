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

## One of `values`, each equally likely; null when there are none.
func pick(values: Array) -> Variant:
	return null if values.is_empty() else values[self.randi_range(0, values.size() - 1)]

## The index of one of `weights`, each as likely as its share of their sum: a
## catch table, a forage table, a loot roll. A weight of 0 or less is never
## picked; -1 when none is above 0.
func pick_weighted(weights: PackedFloat64Array) -> int:
	var total := 0.0
	var last := -1
	for index: int in weights.size():
		if weights[index] > 0.0:
			total += weights[index]
			last = index
	if last < 0:
		return -1
	var roll := _next_float() * total
	var cursor := 0.0
	for index: int in last:
		if weights[index] > 0.0:
			cursor += weights[index]
			if roll < cursor:
				return index
	# The sum rounded down past the roll: the last weight takes the rest.
	return last

## A point of `area`, each equally likely.
func point_in(area: Rect2) -> Vector2:
	var x := self.randf_range(area.position.x, area.end.x)
	return Vector2(x, self.randf_range(area.position.y, area.end.y))

## `count` points of `area` (rocks on a mine floor, enemies in an arena), each
## at least `spacing` from the others and from `taken`, snapped to a grid of
## `snap` unless it is zero, and taken by `accept` (`func(point: Vector2) ->
## bool`: clear of a doorway) when it is given. Each point is drawn up to
## `attempts` times; when no draw is clear, the last one drawn is kept, so a
## crowded area still gets every point.
func scatter(area: Rect2, count: int, spacing: float, taken := PackedVector2Array(), snap := Vector2.ZERO, accept := Callable(), attempts := 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	var near := taken.duplicate()
	for _point: int in maxi(count, 0):
		var point := area.get_center()
		for _attempt: int in maxi(attempts, 1):
			point = point_in(area)
			if snap != Vector2.ZERO:
				point = point.snapped(snap)
			if _is_clear(point, near, spacing) and (not accept.is_valid() or accept.call(point)):
				break
		points.append(point)
		near.append(point)
	return points

static func _is_clear(point: Vector2, near: PackedVector2Array, spacing: float) -> bool:
	var reach := spacing * spacing
	for other: Vector2 in near:
		if point.distance_squared_to(other) < reach:
			return false
	return true

# Inside this class a bare `randi()`, `randf()` or `randf_range()` is the
# engine's global generator: the methods above draw through these, or call the
# stream's own on `self`.
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
