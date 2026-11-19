class_name MFarmFarmService
extends Node

## The state of MFarm's land (`Farmland`), location by location: the soil the
## player dug and watered, what grows on each cell, the items lying on the
## ground, the scenery the player took and the furniture they built.
## Scenes draw it (`MFarmFarmGrid`) and come and go; the state stays.
##
## Each new day dug soil dries, crops grow a day, and soil left unplanted for
## more than `DAYS_SOIL_STAYS_DUG` days fills in again. A harvest regrows the
## crop, turns it into what it leaves (a tree its stump) or clears the cell.
##
## Everything persists in `WorldState` under `STATE_KEY`.

## Emitted when a cell's soil or crop changed (`cell` is the cell) or all of a
## location's did (a new day, a load: `all` is true).
signal land_changed(location_id: StringName, cell: Vector2i, all: bool)
signal items_changed(location_id: StringName)
signal furniture_changed(location_id: StringName)

const STATE_KEY := &"mfarm:farm"
const DAYS_SOIL_STAYS_DUG := 5

## location id -> {"tiles": {Vector2i: tile}, "generated": {key: true},
## "taken": {key: true}, "dropped": Array[Dictionary], "furniture": Array[Dictionary]}.
## A tile is {"dug": int days since dug or -1, "watered": bool,
## "seed": StringName, "growth": int days, "actions": int, "regrown": int}.
var _locations: Dictionary = {}
var _next_item_id := 1
var _loading := false

func _ready() -> void:
	WorldState.changed.connect(_on_world_changed)
	WorldClock.day_changed.connect(_on_day_changed)
	_load()

func get_tile(location_id: StringName, cell: Vector2i) -> Dictionary:
	var tiles: Dictionary = _location(location_id).tiles
	return (tiles[cell] as Dictionary).duplicate() if tiles.has(cell) else _new_tile()

## The cells of a location that hold soil or a crop.
func get_cells(location_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_location(location_id).tiles.keys())
	return result

func is_dug(location_id: StringName, cell: Vector2i) -> bool:
	return int(get_tile(location_id, cell).dug) >= 0

func is_watered(location_id: StringName, cell: Vector2i) -> bool:
	return bool(get_tile(location_id, cell).watered)

func get_crop(location_id: StringName, cell: Vector2i) -> MFarmCropData:
	return MFarmCropData.find(get_tile(location_id, cell).seed)

func is_ripe(location_id: StringName, cell: Vector2i) -> bool:
	var tile := get_tile(location_id, cell)
	var crop := MFarmCropData.find(tile.seed)
	return crop != null and crop.is_ripe(int(tile.growth))

func can_dig(location_id: StringName, cell: Vector2i) -> bool:
	var map := MFarmMapData.find(location_id)
	var tile := get_tile(location_id, cell)
	return map != null and map.can_dig(cell) and int(tile.dug) < 0 and tile.seed == &""

func dig(location_id: StringName, cell: Vector2i) -> bool:
	if not can_dig(location_id, cell):
		return false
	_update_tile(location_id, cell, {"dug": 0})
	return true

func can_water(location_id: StringName, cell: Vector2i) -> bool:
	return is_dug(location_id, cell) and not is_watered(location_id, cell)

func water(location_id: StringName, cell: Vector2i) -> bool:
	if not can_water(location_id, cell):
		return false
	_update_tile(location_id, cell, {"watered": true})
	return true

## Whether `seed_id` can be planted on the cell today: dug soil with nothing
## on it, in a season the seed grows in.
func can_plant(location_id: StringName, cell: Vector2i, seed_id: StringName) -> bool:
	var crop := MFarmCropData.find(seed_id)
	var tile := get_tile(location_id, cell)
	return crop != null and int(tile.dug) >= 0 and tile.seed == &"" and crop.can_grow_in(WorldClock.get_season_index())

## Plants `seed_id` on the cell: on dug soil in season, or, `placed`, anywhere
## (what a scene places: trees, rocks), `growth` days grown.
func plant(location_id: StringName, cell: Vector2i, seed_id: StringName, growth := 0, placed := false) -> bool:
	if MFarmCropData.find(seed_id) == null or get_tile(location_id, cell).seed != &"":
		return false
	if not placed and not can_plant(location_id, cell, seed_id):
		return false
	_update_tile(location_id, cell, {"seed": seed_id, "growth": maxi(growth, 0), "actions": 0, "regrown": 0})
	return true

## Whether `tool_id` can work the crop on the cell now: it is ripe and the
## tool is one that harvests it.
func can_harvest(location_id: StringName, cell: Vector2i, tool_id: StringName) -> bool:
	var crop := get_crop(location_id, cell)
	return crop != null and is_ripe(location_id, cell) and crop.get_required_actions(tool_id) > 0

## One use of `tool_id` on the crop of the cell. Returns {} when the tool
## cannot work it, else {"crop": MFarmCropData, "harvested": bool}: the
## harvest happens with the last use the crop needs, and the cell then
## regrows, turns into what the crop leaves or clears.
func work_crop(location_id: StringName, cell: Vector2i, tool_id: StringName) -> Dictionary:
	if not can_harvest(location_id, cell, tool_id):
		return {}
	var tile := get_tile(location_id, cell)
	var crop := MFarmCropData.find(tile.seed)
	var actions := int(tile.actions) + 1
	if actions < crop.get_required_actions(tool_id):
		_update_tile(location_id, cell, {"actions": actions})
		return {"crop": crop, "harvested": false}
	if crop.days_to_regrow > 0 and int(tile.regrown) < crop.regrow_times:
		_update_tile(location_id, cell, {"growth": crop.get_total_days() - crop.days_to_regrow, "actions": 0, "regrown": int(tile.regrown) + 1})
	elif crop.transfer_item_id != &"":
		_update_tile(location_id, cell, {"seed": crop.transfer_item_id, "growth": 0, "actions": 0, "regrown": 0})
	else:
		_update_tile(location_id, cell, {"seed": &"", "growth": 0, "actions": 0, "regrown": 0})
	return {"crop": crop, "harvested": true}

## Whether a scene's placed thing under `key` (a tree, a rock) was already
## put on the land once.
func is_generated(location_id: StringName, key: String) -> bool:
	return _location(location_id).generated.has(key)

func mark_generated(location_id: StringName, key: String) -> void:
	_location(location_id).generated[key] = true
	_save()

## Whether a scene's item under `key` (grass, an item lying there) was taken.
func is_taken(location_id: StringName, key: String) -> bool:
	return _location(location_id).taken.has(key)

func mark_taken(location_id: StringName, key: String) -> void:
	_location(location_id).taken[key] = true
	_save()

## The items lying on a location's ground: [{"id": int, "item": StringName, "position": Vector2}].
func get_dropped(location_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _location(location_id).dropped:
		result.append(entry.duplicate())
	return result

## Leaves `item_id` on the ground; returns its id there.
func add_dropped(location_id: StringName, item_id: StringName, at: Vector2) -> int:
	var entry := {"id": _next_item_id, "item": item_id, "position": at}
	_next_item_id += 1
	(_location(location_id).dropped as Array).append(entry)
	_save()
	items_changed.emit(location_id)
	return int(entry.id)

func remove_dropped(location_id: StringName, dropped_id: int) -> void:
	var dropped: Array = _location(location_id).dropped
	for index: int in dropped.size():
		if int(dropped[index].id) == dropped_id:
			dropped.remove_at(index)
			_save()
			return

## The furniture built in a location: [{"item": StringName, "position": Vector2, "box": StringName}].
func get_furniture(location_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _location(location_id).furniture:
		result.append(entry.duplicate())
	return result

## Records furniture built from `blueprint_id` at `at`; a box gets a bag of
## its own, named by the returned entry's "box".
func add_furniture(location_id: StringName, blueprint_id: StringName, at: Vector2) -> Dictionary:
	var furniture: Array = _location(location_id).furniture
	var entry := {"item": blueprint_id, "position": at, "box": StringName("box:%s:built_%d" % [location_id, _next_item_id])}
	_next_item_id += 1
	furniture.append(entry)
	_save()
	furniture_changed.emit(location_id)
	return entry.duplicate()

# A new day: soil dries and crops grow; soil left empty too long fills in.
func _on_day_changed(_day: int) -> void:
	for location_id: StringName in _locations:
		var tiles: Dictionary = _locations[location_id].tiles
		for cell: Vector2i in tiles.keys():
			var tile: Dictionary = tiles[cell]
			tile.watered = false
			if int(tile.dug) >= 0:
				tile.dug = int(tile.dug) + 1
			if tile.seed != &"":
				tile.growth = int(tile.growth) + 1
			elif int(tile.dug) > DAYS_SOIL_STAYS_DUG:
				tile.dug = -1
			if int(tile.dug) < 0 and tile.seed == &"":
				tiles.erase(cell)
		land_changed.emit(location_id, Vector2i.ZERO, true)
	_save()

func _update_tile(location_id: StringName, cell: Vector2i, changes: Dictionary) -> void:
	var tiles: Dictionary = _location(location_id).tiles
	var tile: Dictionary = tiles.get(cell, _new_tile())
	tile.merge(changes, true)
	if int(tile.dug) < 0 and tile.seed == &"":
		tiles.erase(cell)
	else:
		tiles[cell] = tile
	_save()
	land_changed.emit(location_id, cell, false)

static func _new_tile() -> Dictionary:
	return {"dug": -1, "watered": false, "seed": &"", "growth": 0, "actions": 0, "regrown": 0}

func _location(location_id: StringName) -> Dictionary:
	if not _locations.has(location_id):
		_locations[location_id] = {"tiles": {}, "generated": {}, "taken": {}, "dropped": [], "furniture": []}
	return _locations[location_id]

func _save() -> void:
	if _loading:
		return
	var data: Dictionary = {}
	for location_id: StringName in _locations:
		var location: Dictionary = _locations[location_id]
		var tiles: Array = []
		for cell: Vector2i in location.tiles:
			var tile: Dictionary = location.tiles[cell]
			tiles.append([cell.x, cell.y, int(tile.dug), bool(tile.watered), String(tile.seed), int(tile.growth), int(tile.actions), int(tile.regrown)])
		var dropped: Array = []
		for entry: Dictionary in location.dropped:
			dropped.append([String(entry.item), (entry.position as Vector2).x, (entry.position as Vector2).y])
		var furniture: Array = []
		for entry: Dictionary in location.furniture:
			furniture.append([String(entry.item), (entry.position as Vector2).x, (entry.position as Vector2).y, String(entry.box)])
		data[String(location_id)] = {"tiles": tiles, "generated": location.generated.keys(), "taken": location.taken.keys(), "dropped": dropped, "furniture": furniture}
	WorldState.set_value(STATE_KEY, {"locations": data, "next": _next_item_id})

func _on_world_changed(key: StringName, _value: Variant) -> void:
	if key == &"":
		_load()

# Reads the land back from the world, keeping current crops and items only.
func _load() -> void:
	_loading = true
	_locations.clear()
	var state: Variant = WorldState.get_value(STATE_KEY)
	var locations: Variant = (state as Dictionary).get("locations", {}) if state is Dictionary else {}
	_next_item_id = maxi(SaveValues.count((state as Dictionary).get("next", 1)) if state is Dictionary else 1, 1)
	if locations is Dictionary:
		for raw_id: Variant in locations:
			if locations[raw_id] is Dictionary:
				_read_location(StringName(String(raw_id)), locations[raw_id])
	_loading = false
	for location_id: StringName in _locations:
		land_changed.emit(location_id, Vector2i.ZERO, true)
		items_changed.emit(location_id)
		furniture_changed.emit(location_id)

func _read_location(location_id: StringName, raw: Dictionary) -> void:
	var location := _location(location_id)
	for entry: Variant in _array(raw.get("tiles")):
		if not entry is Array or (entry as Array).size() != 8:
			continue
		var seed := StringName(String(entry[4]))
		if seed != &"" and MFarmCropData.find(seed) == null:
			seed = &""
		var tile := {"dug": SaveValues.whole_number_or(entry[2], -1), "watered": entry[3] == true, "seed": seed,
			"growth": SaveValues.count(entry[5]), "actions": SaveValues.count(entry[6]), "regrown": SaveValues.count(entry[7])}
		if int(tile.dug) >= 0 or seed != &"":
			location.tiles[Vector2i(SaveValues.whole_number_or(entry[0], 0), SaveValues.whole_number_or(entry[1], 0))] = tile
	for key: Variant in _array(raw.get("generated")):
		location.generated[String(key)] = true
	for key: Variant in _array(raw.get("taken")):
		location.taken[String(key)] = true
	for entry: Variant in _array(raw.get("dropped")):
		if entry is Array and (entry as Array).size() == 3 and MFarmItemData.find(StringName(String(entry[0]))) != null:
			location.dropped.append({"id": _next_item_id, "item": StringName(String(entry[0])), "position": Vector2(float(entry[1]), float(entry[2]))})
			_next_item_id += 1
	for entry: Variant in _array(raw.get("furniture")):
		if entry is Array and (entry as Array).size() == 4 and MFarmBlueprintData.find(StringName(String(entry[0]))) != null:
			location.furniture.append({"item": StringName(String(entry[0])), "position": Vector2(float(entry[1]), float(entry[2])), "box": StringName(String(entry[3]))})

static func _array(value: Variant) -> Array:
	return value if value is Array else []
