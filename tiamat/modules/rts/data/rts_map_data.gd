class_name RtsMapData
extends ContentEntry

## A command battle a game sets up: the size of its field in pixels, the
## rectangles no unit walks through (rocks, walls, water), the side the
## player commands, the units each side starts with, and whether the units the
## player does not command march on their foes or wait for them. The rts
## module's minigame plays it (`RtsBattleGame`, setting `map`).

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

## The map with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RtsMapData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RtsMapData

## The running game's maps, sorted by id.
static func find_all() -> Array[RtsMapData]:
	var result: Array[RtsMapData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
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
		if FactionData.are_hostile(placement.faction_id, player_faction_id):
			others += 1
		else:
			players += 1
	if players == 0:
		problems.append("places no unit on the player's side '%s'" % player_faction_id)
	if others == 0:
		problems.append("places no unit against the player")
	return problems
