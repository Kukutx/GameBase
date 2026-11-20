class_name RtsSides
extends RefCounted

## The factions of a battle, each a side numbered in the order it joined
## (`RtsUnit.side`), and which sides fight each other: a faction's hostility
## to every other (`FactionData.are_hostile()`) is asked once, as it joins, so
## a step of the battle reads it from a table.

# faction -> its side.
var _sides: Dictionary[StringName, int] = {}
# Whether two sides fight, at first * count + second.
var _hostility := PackedByteArray()
# The sides each side fights, and those it does not, itself among them.
var _foes: Array[PackedInt32Array] = []
var _friends: Array[PackedInt32Array] = []
var _every := PackedInt32Array()

## The side of `faction`; a faction new to the battle joins as the next side.
func side_of(faction: StringName) -> int:
	if _sides.has(faction):
		return _sides[faction]
	_sides[faction] = _sides.size()
	var factions := _sides.keys()
	var count := factions.size()
	_hostility.resize(count * count)
	_foes.resize(count)
	_friends.resize(count)
	_every.append(count - 1)
	for first: int in count:
		_foes[first] = PackedInt32Array()
		_friends[first] = PackedInt32Array()
		for second: int in count:
			var hostile := FactionData.are_hostile(factions[first], factions[second])
			_hostility[first * count + second] = 1 if hostile else 0
			if hostile:
				_foes[first].append(second)
			else:
				_friends[first].append(second)
	return _sides[faction]

## How many sides have joined.
func count() -> int:
	return _sides.size()

## Whether side `first` fights side `second`.
func are_hostile(first: int, second: int) -> bool:
	return _hostility[first * _sides.size() + second] == 1

## The sides `side` fights.
func foes_of(side: int) -> PackedInt32Array:
	return _foes[side]

## The sides `side` does not fight, itself among them.
func friends_of(side: int) -> PackedInt32Array:
	return _friends[side]

## Every side.
func every() -> PackedInt32Array:
	return _every
