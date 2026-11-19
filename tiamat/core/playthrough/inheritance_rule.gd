class_name InheritanceRule
extends Resource

## One thing a new playthrough or a sequel carries over from the game before
## it (`Playthrough`): the rule takes its part of the game as it is
## (`capture()`) and gives it to the new game once its services are reset
## (`apply()`). The part is plain data (booleans, numbers, text, arrays and
## dictionaries), so a legacy file can hold it; it may come back from JSON or
## from a file edited by hand, so `apply()` takes only what it understands.
## A game lists its rules in `GameDefinition.inheritance`.

## The name of the part: a sequel's rule with the same key reads it.
@export var key: StringName

## Its part of the running game.
func capture() -> Variant:
	return null

## Gives its part, `data`, to the new game.
func apply(_data: Variant) -> void:
	pass

## What is wrong with the rule, each problem a phrase.
func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	return PackedStringArray()

## What is wrong with a game's rules, each problem a sentence: an empty slot, a
## rule without a key, two rules with the same key, and each rule's own.
static func find_list_problems(rules: Array[InheritanceRule], registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var keys: Dictionary = {}
	for index: int in rules.size():
		var rule := rules[index]
		if rule == null:
			problems.append("inheritance rule %d is empty" % (index + 1))
			continue
		if rule.key == &"":
			problems.append("inheritance rule %d has no key" % (index + 1))
		elif keys.has(rule.key):
			problems.append("inheritance rules %d and %d share key '%s'" % [int(keys[rule.key]) + 1, index + 1, rule.key])
		else:
			keys[rule.key] = index
		for problem: String in rule.find_problems(registry):
			problems.append("inheritance rule '%s' %s" % [rule.key, problem])
	return problems
