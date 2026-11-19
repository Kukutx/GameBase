class_name MFarmCursor
extends Node2D

## MFarm's mouse pointer, drawn from the old project's cursor pack: a plain
## arrow over the interface or with empty hands, and a seed, item or tool
## pointer for what the player holds. Where the held item cannot be used the
## pointer turns red. A blueprint in hand shows the piece of furniture on
## the cell under the pointer, red where it cannot be built.

const NORMAL: Texture2D = preload("res://game/unity/art/cursors/cursor(11).tres")
const TOOL: Texture2D = preload("res://game/unity/art/cursors/cursor(8).tres")
const SEED: Texture2D = preload("res://game/unity/art/cursors/cursor(3).tres")
const ITEM: Texture2D = preload("res://game/unity/art/cursors/cursor(5).tres")
const INVALID := Color(1, 0, 0, 0.5)
## A blueprint's furniture shows half seen where it can be built.
const PREVIEW := Color(1, 1, 1, 0.5)

@onready var _pointer: Sprite2D = $Screen/Pointer
@onready var _preview: Sprite2D = $Preview

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	var viewport := get_viewport()
	_pointer.position = viewport.get_mouse_position()
	var item := Bags.get_selected_item()
	var over_ui := viewport.gui_get_hovered_control() != null or get_tree().paused
	_preview.visible = false
	if item == null or over_ui or InputLock.is_locked():
		_show(NORMAL, true)
		return
	var grid := get_tree().get_first_node_in_group(&"mfarm_farm_grid") as MFarmFarmGrid
	var target := get_global_mouse_position()
	var holder := get_parent() as Node2D
	var valid := holder != null and grid != null and grid.can_use_item(item, target, holder.global_position)
	if item.item_type == MFarmItemData.ItemType.FURNITURE:
		_preview.visible = true
		MFarmSpritePivot.apply(_preview, item.get_world_texture())
		_preview.global_position = MFarmMapData.cell_center(MFarmMapData.cell_of(target))
		_preview.modulate = PREVIEW if valid else INVALID
		_show(TOOL, valid)
		return
	_show(_pointer_for(item), valid)

func _show(texture: Texture2D, valid: bool) -> void:
	_pointer.texture = texture
	_pointer.modulate = Color.WHITE if valid else INVALID

static func _pointer_for(item: MFarmItemData) -> Texture2D:
	match item.item_type:
		MFarmItemData.ItemType.SEED:
			return SEED
		MFarmItemData.ItemType.COMMODITY:
			return ITEM
		MFarmItemData.ItemType.REAPABLE_SCENERY:
			return NORMAL
	return TOOL
