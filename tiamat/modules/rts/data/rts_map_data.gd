class_name RtsMapData
extends ContentEntry

## A command battle a game sets up: the size of its field in pixels, the
## rectangles no unit walks through (rocks, walls, water), the ground a side
## wins by holding (`goal_area`), how long it lasts at most (`time_limit`), the
## side the player commands, the units each side starts with, and whether the
## units the player does not command march on their foes or wait for them. The
## rts module's minigame plays it (`RtsBattleGame`, setting `map`).

const KIND := &"rts_map"
## The smallest and largest field, in pixels.
const MIN_SIZE := Vector2(64.0, 64.0)
const MAX_SIZE := Vector2(2048.0, 2048.0)

@export var display_name := ""
@export var size := Vector2(480.0, 216.0)
@export var obstacles: Array[Rect2] = []
## The side the player commands (`FactionData`); its allies fight with it.
@export var player_faction_id: StringName = FactionData.PLAYER
@export var placements: Array[RtsPlacement] = []
## Whether the units the player does not command march on the nearest foe
## when they have nothing to do; if not, they wait where they stand until a
## foe comes in sight, and then go after it as any unit with nothing to do.
@export var computer_advances := true
## The ground a side wins the battle by holding (a camp's fire, a hilltop):
## once units of the side of `goal_faction_id` stood in it with no foe among
## them, healers aside, for `goal_seconds` in all, that side wins (`RtsGoal`),
## the player's when it is theirs; and the units the player does not command
## that advance march on it rather than on their nearest foe. With no area,
## the battle ends only when one side is left.
@export var goal_area := Rect2()
## The seconds of holding the ground that win the battle.
@export_range(1.0, 600.0, 1.0, "suffix:s") var goal_seconds := 30.0
## The side that wins by holding the ground (`FactionData`); empty, the
## player's.
@export var goal_faction_id: StringName
## The most seconds of battle time the battle lasts: once they pass, the side
## of `time_faction_id` wins (`BattleTimeLimit`), the player's when it is
## theirs (a stand to hold out) and the foes' when it is not (a raid to win in
## time); 0, no limit.
@export_range(0.0, 900.0, 1.0, "suffix:s") var time_limit := 0.0
## The side that wins once time runs out (`FactionData`); empty, the player's.
@export var time_faction_id: StringName

## The map with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RtsMapData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RtsMapData

## The running game's maps, sorted by id.
static func find_all() -> Array[RtsMapData]:
	var result: Array[RtsMapData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## How many units the player's side can field: those its placements put on
## it, with a condition or without.
func count_player_side() -> int:
	return placements.filter(func(placement: RtsPlacement) -> bool: return not FactionData.are_hostile(placement.faction_id, player_faction_id)).size()

## The side that wins by holding the ground: `goal_faction_id`, else the
## player's.
func get_goal_faction() -> StringName:
	return goal_faction_id if goal_faction_id != &"" else player_faction_id

## The battle's time limit (`time_limit`), or null when it has none.
func get_time_limit() -> BattleTimeLimit:
	if time_limit <= 0.0:
		return null
	return BattleTimeLimit.new(time_limit, time_faction_id if time_faction_id != &"" else player_faction_id)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if time_limit <= 0.0 and time_faction_id != &"":
		problems.append("names side '%s' that wins once time runs out, but sets no time limit" % time_faction_id)
	if display_name.is_empty():
		problems.append("has no display name")
	if size.x < MIN_SIZE.x or size.y < MIN_SIZE.y or size.x > MAX_SIZE.x or size.y > MAX_SIZE.y:
		problems.append("has size %s outside %s to %s" % [size, MIN_SIZE, MAX_SIZE])
		return problems
	var field := Rect2(Vector2.ZERO, size)
	for obstacle: Rect2 in obstacles:
		if not field.intersects(obstacle):
			problems.append("has obstacle %s outside its field" % obstacle)
	var navigation := RtsNavigation.new(size, obstacles)
	if goal_area.has_area() and not navigation.is_open(goal_area.get_center()):
		problems.append("holds ground %s whose middle is in an obstacle or outside its field" % goal_area)
	var players := 0
	var others := 0
	for placement: RtsPlacement in placements:
		if placement == null:
			problems.append("has an empty placement")
			continue
		if not registry.has_entry(RtsUnitData.KIND, placement.unit_id):
			problems.append("places unknown unit '%s'" % placement.unit_id)
		if placement.faction_id == &"":
			problems.append("places unit '%s' on no side" % placement.unit_id)
		if not navigation.is_open(placement.position):
			problems.append("places unit '%s' at %s, in an obstacle or outside its field" % [placement.unit_id, placement.position])
		# A battle starts with a unit on each side whatever the conditions.
		if not placement.condition.is_empty():
			continue
		if FactionData.are_hostile(placement.faction_id, player_faction_id):
			others += 1
		else:
			players += 1
	if players == 0:
		problems.append("places no unit on the player's side '%s' that joins without a condition" % player_faction_id)
	if others == 0:
		problems.append("places no unit against the player that joins without a condition")
	return problems
