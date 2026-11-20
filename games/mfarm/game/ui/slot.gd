class_name MFarmSlot
extends Control

## One slot of a bag on screen: its item's icon and amount, and the highlight
## of the item in the player's hands. Clicking a slot of the player's bag puts
## its item in their hands; dragging moves a stack between slots and bags, to
## a shop as a sale, from one as a purchase, and out onto the ground.

signal hovered(slot: MFarmSlot, inside: bool)

const SIZE := Vector2(20, 20)

var bag_key := &""
var index := 0
var menu: Node

var _icon: TextureRect
var _amount: Label
var _highlight: TextureRect
var _dragging := false

func _init(slot_bag: StringName, slot_index: int, slot_size := SIZE) -> void:
	bag_key = slot_bag
	index = slot_index
	custom_minimum_size = slot_size
	size = slot_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A finger beside a slot on a phone still taps it.
	add_to_group(TouchTarget.GROUP)
	var background := MFarmUiArt.image(MFarmUiArt.texture("ui_slot"), slot_size)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(background)
	_icon = MFarmUiArt.image(null, slot_size - Vector2(4, 4))
	_icon.position = Vector2(2, 2)
	add_child(_icon)
	_amount = MFarmUiArt.label("", 8, MFarmUiArt.LIGHT_TEXT_COLOR)
	_amount.add_theme_constant_override(&"outline_size", 2)
	_amount.add_theme_color_override(&"font_outline_color", Color(0.2, 0.12, 0.08))
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# The count and its outline end on the slot's bottom edge: the action bar
	# sits on the screen's, and a count drawn lower lost its last rows there.
	_amount.size = slot_size
	_amount.position = Vector2(-1, 0)
	add_child(_amount)
	_highlight = MFarmUiArt.image(MFarmUiArt.texture("ui_select"), slot_size)
	_highlight.stretch_mode = TextureRect.STRETCH_SCALE
	_highlight.visible = false
	add_child(_highlight)
	mouse_entered.connect(func() -> void: hovered.emit(self, true))
	mouse_exited.connect(func() -> void: hovered.emit(self, false))

func refresh() -> void:
	var slot := Bags.get_slot(bag_key, index)
	var item := MFarmItemData.find(slot.item)
	_icon.texture = item.icon if item != null else null
	_amount.text = str(slot.amount) if item != null and int(slot.amount) > 1 else ""
	_highlight.visible = bag_key == Bags.PLAYER and index == Bags.selected and item != null

func get_item() -> MFarmItemData:
	return MFarmItemData.find(Bags.get_slot(bag_key, index).item)

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and bag_key == Bags.PLAYER and get_item() != null:
		Bags.select(index)
		accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
	var item := get_item()
	if item == null:
		return null
	var preview := MFarmUiArt.image(item.icon, SIZE)
	preview.position = -SIZE * 0.5
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	_dragging = true
	return {"mfarm_slot": true, "bag": bag_key, "index": index}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("mfarm_slot")

func _drop_data(_at: Vector2, data: Variant) -> void:
	if menu != null:
		menu.call(&"move_stack", StringName(data.bag), int(data.index), bag_key, index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		if menu != null and not get_viewport().gui_is_drag_successful():
			menu.call(&"drop_on_ground", bag_key, index)
