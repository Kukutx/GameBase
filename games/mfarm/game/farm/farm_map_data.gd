class_name MFarmMapData
extends ContentEntry

## What each cell of a location allows: digging, dropping items, placing
## furniture, and where townsfolk cannot walk. Its id is the location's.
## Cells count in Godot's grid, x to the right and y down, one per 20 pixels.

const KIND := &"mfarm_map"
const CELL_SIZE := 20

## The grid townsfolk walk on: its top left cell and its size in cells.
@export var grid_origin := Vector2i.ZERO
@export var grid_size := Vector2i.ONE
@export var diggable: Array[Vector2i] = []
@export var drop_item: Array[Vector2i] = []
@export var place_furniture: Array[Vector2i] = []
@export var npc_obstacle: Array[Vector2i] = []

var _lookup: Dictionary = {}

static func find(entry_id: StringName) -> MFarmMapData:
	if entry_id == &"" or ContentRegistry.active == null:
		return null
	return ContentRegistry.active.get_entry(KIND, entry_id) as MFarmMapData

static func cell_of(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / CELL_SIZE), floori(world_position.y / CELL_SIZE))

static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * (CELL_SIZE * 0.5)

func can_dig(cell: Vector2i) -> bool:
	return _has(&"diggable", cell)

func can_drop(cell: Vector2i) -> bool:
	return _has(&"drop_item", cell)

func can_place_furniture(cell: Vector2i) -> bool:
	return _has(&"place_furniture", cell)

func is_npc_obstacle(cell: Vector2i) -> bool:
	return _has(&"npc_obstacle", cell)

func get_grid_rect() -> Rect2i:
	return Rect2i(grid_origin, grid_size)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not registry.has_entry(WorldLocationData.KIND, id):
		problems.append("is for unknown location '%s'" % id)
	if grid_size.x <= 0 or grid_size.y <= 0:
		problems.append("has an empty grid")
	return problems

func _has(property: StringName, cell: Vector2i) -> bool:
	if _lookup.is_empty():
		for name: StringName in [&"diggable", &"drop_item", &"place_furniture", &"npc_obstacle"]:
			var cells: Dictionary = {}
			for entry: Vector2i in get(name):
				cells[entry] = true
			_lookup[name] = cells
	return (_lookup[property] as Dictionary).has(cell)
