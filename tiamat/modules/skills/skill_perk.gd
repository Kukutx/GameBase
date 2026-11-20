class_name SkillPerk
extends Resource

## What a skill grants from a level on, until a later perk of the same skill
## takes its place: multipliers and bonuses of stats registered with
## `GameStats`.

## The skill level that unlocks the perk.
@export_range(2, 100, 1) var level := 5
## The perk's name as the player reads it ("Angler I"), before what it
## changes (`describe()`).
@export var description: String
## Multiplier of each stat the perk changes, as stat -> factor.
@export var multipliers: Dictionary[StringName, float] = {}
## Amount added to each stat the perk changes, as stat -> amount.
@export var bonuses: Dictionary[StringName, float] = {}

## The perk as the player reads it, translated: its name and what it changes,
## each named stat's change as `GameStats.describe_changes()` reads it
## ("Angler I · Bite wait -10% · Reel window +15%").
func describe() -> String:
	var parts := PackedStringArray([TranslationServer.translate(description)])
	parts.append_array(GameStats.describe_changes(multipliers, bonuses))
	return " · ".join(parts)

## What is wrong with the perk, each problem a phrase.
func find_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if level < 2:
		problems.append("has a level %d perk; a perk unlocks at level 2 or above" % level)
	if description.strip_edges().is_empty():
		problems.append("has a level %d perk without a description" % level)
	if multipliers.is_empty() and bonuses.is_empty():
		problems.append("has a level %d perk that changes no stat" % level)
	for problem: String in GameStats.find_change_problems(multipliers, bonuses):
		problems.append("has a level %d perk that %s" % [level, problem])
	return problems
