class_name LicensedTerrainLayer
extends TileMapLayer

@export_file("*.png") var asset_path: String
@export var atlas_coord := Vector2i.ZERO
@export var tile_size := Vector2i(32, 32)
@export var origin_cell := Vector2i.ZERO
@export var grid_size := Vector2i(1, 1)
@export var enabled_if_available := true

func _ready() -> void:
	if not enabled_if_available or asset_path.is_empty() or not ResourceLoader.exists(asset_path):
		visible = false
		return
	var texture := load(asset_path) as Texture2D
	if texture == null or tile_size.x <= 0 or tile_size.y <= 0:
		visible = false
		return
	var max_coord := Vector2i(texture.get_width() / tile_size.x, texture.get_height() / tile_size.y) - Vector2i.ONE
	if atlas_coord.x < 0 or atlas_coord.y < 0 or atlas_coord.x > max_coord.x or atlas_coord.y > max_coord.y:
		visible = false
		return

	var generated_set := TileSet.new()
	generated_set.tile_size = tile_size
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = tile_size
	source.create_tile(atlas_coord)
	var source_id := generated_set.add_source(source)
	tile_set = generated_set

	clear()
	for y in range(maxi(grid_size.y, 0)):
		for x in range(maxi(grid_size.x, 0)):
			set_cell(origin_cell + Vector2i(x, y), source_id, atlas_coord)
	visible = true
