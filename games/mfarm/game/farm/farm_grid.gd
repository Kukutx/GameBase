class_name MFarmFarmGrid
extends Node2D

## A location's land as `Farmland` keeps it: dug and watered soil, crops, items
## lying on the ground and built furniture, kept in step with the state. It
## also carries out what the player does with the item in their hands on a
## cell (`use_item()`), and tells whether they can (`can_use_item()`).

const DIG_TILE: MFarmRuleTile = preload("res://game/data/rule_tiles/dig.tres")
const WATER_TILE: MFarmRuleTile = preload("res://game/data/rule_tiles/water.tres")
const DROPPED_ITEM: PackedScene = preload("res://game/unity/prefabs/item/BounceItemBase.tscn")
## The most weeds one swing of a sickle cuts.
const REAP_LIMIT := 4
const DIG_Z := -400
const WATER_Z := -200
const CELL := MFarmMapData.CELL_SIZE

var location_id := &""
var map: MFarmMapData

var _soil: Node2D
var _water: Node2D
var _crops: Node2D
var _items: Node2D
var _furniture: Node2D
## cell -> {"node": Node2D, "scene": PackedScene, "stage": int, "seed": StringName}
var _crop_nodes: Dictionary = {}
## Cells whose crop plays a fall, left alone until it ends.
var _busy_cells: Dictionary = {}
## dropped id -> MFarmWorldItem
var _dropped_nodes: Dictionary = {}
var _furniture_count := 0
var _random: GameRandomStream

func _ready() -> void:
	add_to_group(&"mfarm_farm_grid")
	location_id = MFarmLocation.id_of(self)
	map = MFarmMapData.find(location_id)
	_random = GameRandom.stream("mfarm_harvest")
	_soil = _layer("Soil", DIG_Z, false)
	_water = _layer("Water", WATER_Z, false)
	_crops = _layer("Crops", 0, true)
	_items = _layer("Items", 0, true)
	_furniture = _layer("Furniture", 0, true)
	Farmland.land_changed.connect(_on_land_changed)
	Farmland.items_changed.connect(_on_items_changed)
	Farmland.furniture_changed.connect(_on_furniture_changed)
	_refresh_land()
	_sync_dropped()
	_sync_furniture()

func _layer(layer_name: String, z: int, sorted: bool) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.y_sort_enabled = sorted
	if not sorted:
		layer.z_index = z
		layer.z_as_relative = false
	add_child(layer)
	return layer

## Whether the player at `from` can use `item` on the cell under `target`.
func can_use_item(item: MFarmItemData, target: Vector2, from: Vector2) -> bool:
	if item == null or map == null:
		return false
	var cell := MFarmMapData.cell_of(target)
	var distance := (cell - MFarmMapData.cell_of(from)).abs()
	if distance.x > item.use_radius or distance.y > item.use_radius:
		return false
	match item.item_type:
		MFarmItemData.ItemType.SEED:
			return Farmland.can_plant(location_id, cell, item.id)
		MFarmItemData.ItemType.COMMODITY:
			return item.can_drop and map.can_drop(cell)
		MFarmItemData.ItemType.FURNITURE:
			var blueprint := MFarmBlueprintData.find(item.id)
			return blueprint != null and map.can_place_furniture(cell) and not _has_furniture_at(cell) and Bags.has_resources(blueprint)
		MFarmItemData.ItemType.HOE_TOOL:
			return Farmland.can_dig(location_id, cell)
		MFarmItemData.ItemType.WATER_TOOL:
			return Farmland.can_water(location_id, cell)
		MFarmItemData.ItemType.CHOP_TOOL, MFarmItemData.ItemType.BREAK_TOOL, MFarmItemData.ItemType.COLLECT_TOOL:
			return Farmland.can_harvest(location_id, cell, item.id) and not _busy_cells.has(cell)
		MFarmItemData.ItemType.REAP_TOOL:
			return not _reapables_near(target, item).is_empty()
	return false

## Uses `item` on the cell under `target`, the player standing at `from`;
## false when nothing happened.
func use_item(item: MFarmItemData, target: Vector2, from: Vector2) -> bool:
	if not can_use_item(item, target, from):
		return false
	var cell := MFarmMapData.cell_of(target)
	match item.item_type:
		MFarmItemData.ItemType.SEED:
			if Bags.remove_item(Bags.PLAYER, item.id, 1) and Farmland.plant(location_id, cell, item.id):
				GameAudio.play_cue(&"sfx_plant")
				return true
		MFarmItemData.ItemType.COMMODITY:
			if Bags.remove_item(Bags.PLAYER, item.id, 1):
				drop_item(item.id, target, from)
				return true
		MFarmItemData.ItemType.FURNITURE:
			return _build(item, cell)
		MFarmItemData.ItemType.HOE_TOOL:
			GameAudio.play_cue(&"sfx_hoe")
			return Farmland.dig(location_id, cell)
		MFarmItemData.ItemType.WATER_TOOL:
			GameAudio.play_cue(&"sfx_water")
			return Farmland.water(location_id, cell)
		MFarmItemData.ItemType.CHOP_TOOL, MFarmItemData.ItemType.BREAK_TOOL, MFarmItemData.ItemType.COLLECT_TOOL:
			return _work_crop(cell, item, from)
		MFarmItemData.ItemType.REAP_TOOL:
			return _reap(target, item, from)
	return false

## Leaves `item_id` on the ground at `at`, thrown there from `from`.
func drop_item(item_id: StringName, at: Vector2, from: Vector2) -> void:
	var dropped_id := Farmland.add_dropped(location_id, item_id, at)
	var node := _dropped_nodes.get(dropped_id) as MFarmWorldItem
	if node != null:
		node.bounce_from(from)

func _work_crop(cell: Vector2i, item: MFarmItemData, from: Vector2) -> bool:
	var result := Farmland.work_crop(location_id, cell, item.id)
	if result.is_empty():
		return false
	var crop: MFarmCropData = result.crop
	var center := MFarmMapData.cell_center(cell)
	var from_left := from.x < center.x
	var node: MFarmCrop = _crop_node(cell)
	if crop.sound_cue_id != &"":
		GameAudio.play_cue(crop.sound_cue_id)
	if crop.effect != MFarmCropData.Effect.NONE:
		MFarmHarvestEffect.spawn(self, crop.effect, center + crop.effect_offset)
	if not result.harvested:
		if crop.has_animation and node != null:
			node.play_hit(from_left)
		return true
	if crop.generate_at_player:
		_give(crop, center, from, from_left)
		return true
	if crop.has_animation and node != null:
		_fell(cell, crop, node, from, from_left)
		return true
	_give(crop, center, from, from_left)
	return true

# A tree falls away from the player, then leaves its stump and what it gives.
func _fell(cell: Vector2i, crop: MFarmCropData, node: MFarmCrop, from: Vector2, from_left: bool) -> void:
	_busy_cells[cell] = true
	GameAudio.play_cue(&"sfx_tree_falling")
	var seconds := node.play_fall(from_left)
	await get_tree().create_timer(maxf(seconds, 0.1)).timeout
	_busy_cells.erase(cell)
	if not is_inside_tree():
		return
	_refresh_crop(cell)
	_give(crop, MFarmMapData.cell_center(cell), from, from_left)

# What a harvest gives: into the player's bag, or onto the ground around the
# crop, on the side away from the player.
func _give(crop: MFarmCropData, center: Vector2, from: Vector2, from_left: bool) -> void:
	for index: int in crop.produced_items.size():
		var amount := _random.randi_range(crop.produce_min[index], maxi(crop.produce_min[index], crop.produce_max[index]))
		var item_id := crop.produced_items[index]
		if crop.generate_at_player:
			var added := Bags.add_item(Bags.PLAYER, item_id, amount)
			if added < amount:
				GameEvents.toast("Your bag is full")
			for left: int in amount - added:
				drop_item(item_id, from + Vector2(_random.randf_range(-8, 8), 6), from)
			continue
		var side := 1.0 if from_left else -1.0
		for count: int in amount:
			var offset := Vector2(_random.randf_range(0.0, crop.spawn_radius.x) * side, _random.randf_range(-crop.spawn_radius.y, crop.spawn_radius.y)) * CELL
			drop_item(item_id, center + offset, center)

func _reap(target: Vector2, item: MFarmItemData, from: Vector2) -> bool:
	var reaped := 0
	for weed: MFarmWorldItem in _reapables_near(target, item):
		if reaped >= REAP_LIMIT:
			break
		var crop := MFarmCropData.find(weed.item_id)
		var at := weed.global_position
		weed.remove()
		reaped += 1
		if crop == null:
			continue
		if crop.sound_cue_id != &"":
			GameAudio.play_cue(crop.sound_cue_id)
		MFarmHarvestEffect.spawn(self, crop.effect, at + crop.effect_offset)
		_give(crop, at, from, from.x < at.x)
	return reaped > 0

func _reapables_near(target: Vector2, item: MFarmItemData) -> Array[MFarmWorldItem]:
	var result: Array[MFarmWorldItem] = []
	var reach := float(maxi(item.use_radius, 1) * CELL)
	for node: Node in get_tree().get_nodes_in_group(&"mfarm_reapable"):
		var weed := node as MFarmWorldItem
		if weed != null and not weed.is_queued_for_deletion() and weed.global_position.distance_to(target) <= reach:
			result.append(weed)
	return result

func _build(item: MFarmItemData, cell: Vector2i) -> bool:
	var blueprint := MFarmBlueprintData.find(item.id)
	if not Bags.remove_item(Bags.PLAYER, item.id, 1):
		return false
	for index: int in blueprint.resources.size():
		Bags.remove_item(Bags.PLAYER, blueprint.resources[index], blueprint.amounts[index])
	Farmland.add_furniture(location_id, item.id, MFarmMapData.cell_center(cell))
	return true

func _has_furniture_at(cell: Vector2i) -> bool:
	for entry: Dictionary in Farmland.get_furniture(location_id):
		if MFarmMapData.cell_of(entry.position) == cell:
			return true
	return false

func _on_land_changed(changed_location: StringName, cell: Vector2i, all: bool) -> void:
	if changed_location != location_id:
		return
	_refresh_soil()
	if all:
		_refresh_land()
	else:
		_refresh_crop(cell)

func _refresh_land() -> void:
	_refresh_soil()
	var cells: Dictionary = {}
	for cell: Vector2i in Farmland.get_cells(location_id):
		cells[cell] = true
	for cell: Vector2i in _crop_nodes.keys():
		cells[cell] = true
	for cell: Vector2i in cells:
		_refresh_crop(cell)

func _refresh_soil() -> void:
	for child: Node in _soil.get_children() + _water.get_children():
		child.queue_free()
	var dug: Dictionary = {}
	var watered: Dictionary = {}
	for cell: Vector2i in Farmland.get_cells(location_id):
		if Farmland.is_dug(location_id, cell):
			dug[cell] = true
			if Farmland.is_watered(location_id, cell):
				watered[cell] = true
	for cell: Vector2i in dug:
		_soil.add_child(_soil_sprite(cell, DIG_TILE.texture_for(MFarmRuleTile.mask_of(cell, dug))))
	for cell: Vector2i in watered:
		_water.add_child(_soil_sprite(cell, WATER_TILE.texture_for(MFarmRuleTile.mask_of(cell, watered))))

static func _soil_sprite(cell: Vector2i, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(cell * CELL)
	return sprite

func _refresh_crop(cell: Vector2i) -> void:
	if _busy_cells.has(cell):
		return
	var tile := Farmland.get_tile(location_id, cell)
	var crop := MFarmCropData.find(tile.seed)
	var shown: Dictionary = _crop_nodes.get(cell, {})
	if crop == null or crop.stage_scenes.is_empty():
		if not shown.is_empty():
			(shown.node as Node).queue_free()
			_crop_nodes.erase(cell)
		return
	var stage := mini(crop.get_stage(int(tile.growth)), crop.stage_scenes.size() - 1)
	var scene := crop.stage_scenes[stage]
	if not shown.is_empty() and shown.scene == scene and int(shown.stage) == stage and shown.seed == crop.id:
		return
	if not shown.is_empty():
		(shown.node as Node).queue_free()
	var node := scene.instantiate() as Node2D
	node.position = MFarmMapData.cell_center(cell)
	_crops.add_child(node)
	var crop_node := _find_crop(node)
	if crop_node != null:
		crop_node.setup(cell, crop, stage)
	_crop_nodes[cell] = {"node": node, "scene": scene, "stage": stage, "seed": crop.id}

func _crop_node(cell: Vector2i) -> MFarmCrop:
	var shown: Dictionary = _crop_nodes.get(cell, {})
	return _find_crop(shown.node) if not shown.is_empty() else null

static func _find_crop(root: Node) -> MFarmCrop:
	if root is MFarmCrop:
		return root
	for child: Node in root.get_children():
		var found := _find_crop(child)
		if found != null:
			return found
	return null

func _on_items_changed(changed_location: StringName) -> void:
	if changed_location == location_id:
		_sync_dropped()

func _sync_dropped() -> void:
	var present: Dictionary = {}
	for entry: Dictionary in Farmland.get_dropped(location_id):
		present[int(entry.id)] = true
		if _dropped_nodes.has(int(entry.id)) and is_instance_valid(_dropped_nodes[int(entry.id)]):
			continue
		var root := DROPPED_ITEM.instantiate() as Node2D
		var item_node := root.get_child(0) as MFarmWorldItem
		item_node.item_id = entry.item
		item_node.dropped_id = int(entry.id)
		root.position = entry.position
		_items.add_child(root)
		_dropped_nodes[int(entry.id)] = item_node
	for dropped_id: int in _dropped_nodes.keys():
		if not present.has(dropped_id):
			var node: Variant = _dropped_nodes[dropped_id]
			if is_instance_valid(node):
				(node as Node).get_parent().queue_free()
			_dropped_nodes.erase(dropped_id)

func _on_furniture_changed(changed_location: StringName) -> void:
	if changed_location == location_id:
		_sync_furniture()

func _sync_furniture() -> void:
	var entries := Farmland.get_furniture(location_id)
	for index: int in range(_furniture_count, entries.size()):
		var entry: Dictionary = entries[index]
		var blueprint := MFarmBlueprintData.find(entry.item)
		if blueprint == null:
			continue
		var node := blueprint.scene.instantiate() as Node2D
		node.position = entry.position
		for box: Node in node.find_children("*", "", true, false):
			if box is MFarmStorageBox:
				(box as MFarmStorageBox).box_key = entry.box
		if node is MFarmStorageBox:
			(node as MFarmStorageBox).box_key = entry.box
		_furniture.add_child(node)
	_furniture_count = entries.size()
