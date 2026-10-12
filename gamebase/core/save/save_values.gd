class_name SaveValues
extends RefCounted

## Reading values back from player data. A save or the profile is JSON, which
## gives every number back as a float, and a file can be edited by hand, so a
## value is taken only in the shape it was written in.

## Beyond 2^53 a float no longer holds every whole number exactly, so an int
## further from 0 does not come back from JSON as it went in.
const MAX_WHOLE_NUMBER := 9007199254740992.0
const MAX_WHOLE_INT := 9007199254740992

## `value` as an int when it is a whole number: an int, or a float JSON gave
## back for one; otherwise null.
static func whole_number(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value) and absf(value) <= MAX_WHOLE_NUMBER:
		return int(value)
	return null
