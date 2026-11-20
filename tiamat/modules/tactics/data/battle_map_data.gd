class_name BattleMapData
extends ContentEntry

## A grid battle a game sets up: the size of its grid, the cells no unit
## stands on or walks through (water, walls), the cells that give cover
## (woods, ruins: a unit there takes `cover_reduction` less damage), the rough
## ground (shallows, mud: entering it takes `rough_cost` steps), the side the
## player commands and the units each side starts with. The tactics module's minigame plays it
## (`GridBattleGame`, setting `map`).

const KIND := &"battle_map"
## The most cells a side of the grid has.
const MAX_SIDE := 32

@export var display_name := ""
@export var size := Vector2i(8, 6)
@export var blocked_cells: Array[Vector2i] = []
## The open cells that give cover to who stands there.
@export var cover_cells: Array[Vector2i] = []
## The share of damage a unit in cover does not take.
@export_range(0.0, 0.9, 0.05) var cover_reduction := 0.3
## The open cells that take more steps to enter.
@export var rough_cells: Array[Vector2i] = []
## The steps entering rough ground takes.
@export_range(2, 4, 1) var rough_cost := 2
## The side the player commands (`FactionData`); its allies fight with it.
@export var player_faction_id: StringName = FactionData.PLAYER
@export var placements: Array[BattlePlacement] = []

## The map with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> BattleMapData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as BattleMapData

## The running game's maps, sorted by id.
static func find_all() -> Array[BattleMapData]:
	var result: Array[BattleMapData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## How many units the player's side can field: those its placements put on
## it, with a condition or without.
func count_player_side() -> int:
	return placements.filter(func(placement: BattlePlacement) -> bool: return not FactionData.are_hostile(placement.faction_id, player_faction_id)).size()

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if size.x < 2 or size.y < 2 or size.x > MAX_SIDE or size.y > MAX_SIDE:
		problems.append("has size %s outside 2x2 to %dx%d" % [size, MAX_SIDE, MAX_SIDE])
		return problems
	var grid := BattleGrid.new(size, blocked_cells)
	for cell: Vector2i in blocked_cells:
		if not grid.has_cell(cell):
			problems.append("blocks cell %s outside its grid" % cell)
	for cell: Vector2i in cover_cells:
		if not grid.is_open(cell):
			problems.append("gives cover on cell %s, which is blocked or outside its grid" % cell)
	for cell: Vector2i in rough_cells:
		if not grid.is_open(cell):
			problems.append("makes cell %s rough, which is blocked or outside its grid" % cell)
	var taken: Dictionary[Vector2i, bool] = {}
	var players := 0
	var others := 0
	for placement: BattlePlacement in placements:
		if placement == null:
			problems.append("has an empty placement")
			continue
		if not registry.has_entry(BattleUnitData.KIND, placement.unit_id):
			problems.append("places unknown unit '%s'" % placement.unit_id)
		if placement.faction_id == &"":
			problems.append("places unit '%s' on no side" % placement.unit_id)
		if not grid.is_open(placement.cell):
			problems.append("places unit '%s' on cell %s, which is blocked or outside its grid" % [placement.unit_id, placement.cell])
		elif taken.has(placement.cell):
			problems.append("places two units on cell %s" % placement.cell)
		taken[placement.cell] = true
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
