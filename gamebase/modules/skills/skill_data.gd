class_name SkillData
extends ContentEntry

## A skill the player levels up with experience (`Skills.add_xp()`), which the
## game grants for what the player does. Its perks change stats from the
## levels they name on.

const KIND := &"skill"

@export var display_name: String
## The name where space is short (the HUD line); empty uses `display_name`.
@export var short_name: String
## Where the skill is listed among the game's skills: lower first, then by id.
@export var order := 0
## Experience to reach level 2, 3, ...: one rising amount per level above 1.
@export var level_xp: PackedInt32Array = PackedInt32Array()
## What the skill grants, by the level that unlocks it.
@export var perks: Array[SkillPerk] = []

## The skill with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> SkillData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as SkillData

## The running game's skills in their listed order.
static func find_all() -> Array[SkillData]:
	var result: Array[SkillData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	result.sort_custom(func(a: SkillData, b: SkillData) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return result

func get_short_name() -> String:
	return short_name if not short_name.is_empty() else display_name

func get_max_level() -> int:
	return level_xp.size() + 1

## The level `xp` experience reaches.
func get_level_for_xp(xp: int) -> int:
	var level := 1
	for amount: int in level_xp:
		if xp < amount:
			break
		level += 1
	return level

## The perk in effect at `level`: the one with the highest level reached, or
## null.
func get_perk_at(level: int) -> SkillPerk:
	var active: SkillPerk = null
	for perk: SkillPerk in perks:
		if perk != null and perk.level <= level and (active == null or perk.level > active.level):
			active = perk
	return active

## The first perk above `level`, or null.
func get_next_perk(level: int) -> SkillPerk:
	var next: SkillPerk = null
	for perk: SkillPerk in perks:
		if perk != null and perk.level > level and (next == null or perk.level < next.level):
			next = perk
	return next

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	var previous := 0
	for amount: int in level_xp:
		if amount <= previous:
			problems.append("needs a rising, positive experience amount for each level")
			break
		previous = amount
	var levels: Dictionary[int, bool] = {}
	for perk: SkillPerk in perks:
		if perk == null:
			problems.append("has an empty perk")
			continue
		if perk.level > get_max_level():
			problems.append("has a level %d perk above its highest level %d" % [perk.level, get_max_level()])
		if levels.has(perk.level):
			problems.append("has two perks at level %d" % perk.level)
		levels[perk.level] = true
		problems.append_array(perk.find_problems())
	return problems
