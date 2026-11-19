class_name MFarmItemTooltip
extends NinePatchRect

## What the item under the cursor is: its name, kind, description and price
## (what a shop asks for it, or pays for it from the player's bag), and for a
## blueprint what building it takes.

const WIDTH := 70.0

var _name: Label
var _kind: Label
var _description: Label
var _price: Label
var _coin: TextureRect
var _resources: NinePatchRect

func _init() -> void:
	var art := MFarmUiArt.panel("ui_pack_00", Vector2(WIDTH, 60))
	texture = art.texture
	patch_margin_left = art.patch_margin_left
	patch_margin_top = art.patch_margin_top
	patch_margin_right = art.patch_margin_right
	patch_margin_bottom = art.patch_margin_bottom
	art.free()
	size = Vector2(WIDTH, 60)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	_name = _line(Vector2(3, 3), 8)
	_kind = _line(Vector2(3, 11), 8)
	_kind.add_theme_color_override(&"font_color", Color(0.45, 0.3, 0.2))
	_description = _line(Vector2(3, 21), 8)
	_description.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_description.size = Vector2(WIDTH - 6, 26)
	_coin = MFarmUiArt.image(MFarmUiArt.texture("ui_pack_05"), Vector2(8, 8))
	MFarmUiArt.place(self, _coin, Vector2(9, 48))
	_price = _line(Vector2(20, 46), 8)
	_resources = MFarmUiArt.panel("ui_pack_00-1", Vector2(WIDTH, 20))
	_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MFarmUiArt.place(self, _resources, Vector2(0, -22))

func show_item(item: MFarmItemData, slot_rect: Rect2, in_shop: bool) -> void:
	_name.text = tr(item.display_name)
	_kind.text = _kind_text(item.item_type)
	_description.text = tr(item.description)
	var priced := item.item_type in [MFarmItemData.ItemType.SEED, MFarmItemData.ItemType.COMMODITY, MFarmItemData.ItemType.FURNITURE]
	_coin.visible = priced
	_price.visible = priced
	_price.text = str(item.price if in_shop else item.get_sell_price())
	_show_resources(MFarmBlueprintData.find(item.id) if item.item_type == MFarmItemData.ItemType.FURNITURE else null)
	position = Vector2(clampf(slot_rect.get_center().x - WIDTH * 0.5, 2, 640 - WIDTH - 2), slot_rect.position.y - size.y - 4)
	if position.y < 24:
		position.y = slot_rect.end.y + 4
	visible = true

func hide_item() -> void:
	visible = false

func _show_resources(blueprint: MFarmBlueprintData) -> void:
	for child: Node in _resources.get_children():
		child.queue_free()
	_resources.visible = blueprint != null
	if blueprint == null:
		return
	for index: int in blueprint.resources.size():
		var resource := MFarmItemData.find(blueprint.resources[index])
		if resource == null:
			continue
		var icon := MFarmUiArt.image(resource.get_world_texture(), Vector2(16, 16))
		MFarmUiArt.place(_resources, icon, Vector2(4 + index * 33, 2))
		var amount := MFarmUiArt.label("%d" % blueprint.amounts[index], 8)
		MFarmUiArt.place(_resources, amount, Vector2(20 + index * 33, 5))

func _line(at: Vector2, font_size: int) -> Label:
	var line := MFarmUiArt.label("", font_size)
	line.size = Vector2(WIDTH - 6, 9)
	line.clip_text = true
	MFarmUiArt.place(self, line, at)
	return line

func _kind_text(item_type: MFarmItemData.ItemType) -> String:
	match item_type:
		MFarmItemData.ItemType.SEED:
			return tr("Seed")
		MFarmItemData.ItemType.COMMODITY:
			return tr("Goods")
		MFarmItemData.ItemType.FURNITURE:
			return tr("Furniture")
		MFarmItemData.ItemType.REAPABLE_SCENERY:
			return tr("Scenery")
	return tr("Tool")
