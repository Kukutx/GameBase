class_name MFarmBagMenu
extends Control

## MFarm's bags on screen: the action bar along the bottom, the player's bag
## (the bag button or the bag control), and a box's or a shop's stock beside
## it. Stacks are dragged between slots; dragged to or from a shop they are
## sold or bought through the trade panel, dragged out onto the land they
## are dropped there. Escape closes what is open. While a box or a shop is
## open the player stands still.

const LOCK := &"mfarm_bag"
const BAG_COLUMNS := 4
const BASE_COLUMNS := 4
## The middle of the screen, where the bags open (`MFarmUiArt.pin()`).
const MIDDLE := Vector2(0.5, 0.5)

var _action_bar: Control
var _player_bag: Control
var _base_bag: Control
var _base_slots: Control
var _money: Label
var _base_key := &""
var _slots: Array[MFarmSlot] = []
var _tooltip: MFarmItemTooltip
var _trade: MFarmTradePanel

func _ready() -> void:
	add_to_group(&"mfarm_bag_menu")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_action_bar()
	_build_player_bag()
	_base_bag = Control.new()
	_base_bag.visible = false
	add_child(_base_bag)
	_tooltip = MFarmItemTooltip.new()
	add_child(_tooltip)
	_trade = MFarmTradePanel.new()
	MFarmUiArt.pin(_trade, _trade.size, MIDDLE, Vector2(-_trade.size.x * 0.5, 75))
	add_child(_trade)
	Bags.bag_changed.connect(_on_bag_changed)
	Bags.selected_changed.connect(func(_index: int) -> void: _refresh_slots(Bags.PLAYER))
	Bags.money_changed.connect(_on_money_changed)
	_refresh_slots(Bags.PLAYER)
	_on_money_changed(Bags.money)

## The box or shop open beside the player's bag, or empty.
func get_open_bag() -> StringName:
	return _base_key if _base_bag.visible else &""

func is_open() -> bool:
	return _player_bag.visible or _base_bag.visible

func toggle_bag() -> void:
	if _base_bag.visible:
		close()
	else:
		_player_bag.visible = not _player_bag.visible
		MFarmUiArt.centre(_player_bag, _player_bag.size)
		_tooltip.hide_item()

## Opens a box's bag beside the player's.
func open_box(box_key: StringName) -> void:
	_open_base(box_key)

## Opens a shop's stock beside the player's bag.
func open_shop(shop_key: StringName, template_id: StringName) -> void:
	Bags.ensure_bag(shop_key, template_id)
	_open_base(shop_key)

func close() -> void:
	_player_bag.visible = false
	_base_bag.visible = false
	_base_key = &""
	_tooltip.hide_item()
	_trade.close()
	InputLock.unlock(LOCK)

## A stack dropped on another slot: moved, or traded with a shop.
func move_stack(from_key: StringName, from_index: int, to_key: StringName, to_index: int) -> void:
	_tooltip.hide_item()
	if MFarmBagService.is_shop(from_key) and to_key == Bags.PLAYER:
		_trade.open_trade(from_key, from_index, false)
	elif from_key == Bags.PLAYER and MFarmBagService.is_shop(to_key):
		_trade.open_trade(to_key, from_index, true)
	elif not MFarmBagService.is_shop(from_key) and not MFarmBagService.is_shop(to_key):
		Bags.move_slot(from_key, from_index, to_key, to_index)

## A stack of the player's bag dragged out onto the land: one of it lands
## under the cursor, when it can be dropped there.
func drop_on_ground(bag_key: StringName, index: int) -> void:
	var item := MFarmItemData.find(Bags.get_slot(bag_key, index).item)
	var grid := get_tree().get_first_node_in_group(&"mfarm_farm_grid") as MFarmFarmGrid
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if bag_key != Bags.PLAYER or item == null or grid == null or player == null or not item.can_drop:
		return
	var target := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	if grid.map == null or not grid.map.can_drop(MFarmMapData.cell_of(target)):
		return
	if Bags.take_from_slot(Bags.PLAYER, index, 1) == 1:
		grid.drop_item(item.id, target, player.global_position)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and (is_open() or _trade.visible):
		close()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_bag") and (not InputLock.is_locked() or InputLock.is_held(LOCK)):
		toggle_bag()
		get_viewport().set_input_as_handled()

func _open_base(bag_key: StringName) -> void:
	_base_key = bag_key
	for child: Node in _base_bag.get_children():
		child.queue_free()
	_slots.assign(_slots.filter(func(slot: MFarmSlot) -> bool: return slot.bag_key == Bags.PLAYER))
	var count := Bags.get_slots(bag_key).size()
	var rows := ceili(float(count) / BASE_COLUMNS)
	var frame := MFarmUiArt.panel("ui_pack_07", Vector2(104, rows * 20 + 28))
	_base_bag.add_child(frame)
	_base_bag.size = frame.size
	var holder := MFarmUiArt.panel("ui_pack_02", Vector2(94, rows * 20 + 8))
	MFarmUiArt.place(frame, holder, Vector2(5, 15))
	var escape := TextureButton.new()
	escape.texture_normal = MFarmUiArt.texture("ui_button_01")
	escape.ignore_texture_size = true
	escape.stretch_mode = TextureButton.STRETCH_SCALE
	escape.size = Vector2(22, 14)
	escape.pressed.connect(close)
	MFarmUiArt.place(frame, escape, Vector2(-3, -9))
	var escape_label := MFarmUiArt.label("ESC", 8, MFarmUiArt.LIGHT_TEXT_COLOR)
	escape_label.size = escape.size
	escape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	escape.add_child(escape_label)
	for index: int in count:
		var slot := _make_slot(bag_key, index)
		MFarmUiArt.place(holder, slot, Vector2(7 + (index % BASE_COLUMNS) * 20, 4 + (index / BASE_COLUMNS) * 20))
	MFarmUiArt.pin(_base_bag, _base_bag.size, MIDDLE, Vector2(-_base_bag.size.x - 8, -_base_bag.size.y * 0.5))
	_base_bag.visible = true
	_player_bag.visible = true
	MFarmUiArt.pin(_player_bag, _player_bag.size, MIDDLE, Vector2(8, -_player_bag.size.y * 0.5))
	_refresh_slots(bag_key)
	InputLock.lock(LOCK, false, self)

func _build_action_bar() -> void:
	_action_bar = MFarmUiArt.panel("ui_slot_frame", Vector2(222, 24))
	MFarmUiArt.pin(_action_bar, _action_bar.size, Vector2(0.5, 1), Vector2(-_action_bar.size.x * 0.5, -_action_bar.size.y))
	add_child(_action_bar)
	var bag_button := TextureButton.new()
	bag_button.texture_normal = MFarmUiArt.texture("ui_pack_03")
	bag_button.ignore_texture_size = true
	bag_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag_button.size = Vector2(20, 20)
	bag_button.tooltip_text = "Bag"
	bag_button.pressed.connect(toggle_bag)
	MFarmUiArt.place(_action_bar, bag_button, Vector2(-22, 2))
	for index: int in Bags.ACTION_BAR_SIZE:
		var slot := _make_slot(Bags.PLAYER, index, Vector2(22, 22))
		MFarmUiArt.place(_action_bar, slot, Vector2(1 + index * 22, 1))

func _build_player_bag() -> void:
	_player_bag = MFarmUiArt.panel("ui_pack_07", Vector2(117, 130))
	_player_bag.visible = false
	add_child(_player_bag)
	var holder := MFarmUiArt.panel("ui_pack_02", Vector2(97, 95))
	MFarmUiArt.place(_player_bag, holder, Vector2(10, 25))
	var bag_size := Bags.get_slots(Bags.PLAYER).size()
	for index: int in range(Bags.ACTION_BAR_SIZE, bag_size):
		var place := index - Bags.ACTION_BAR_SIZE
		var slot := _make_slot(Bags.PLAYER, index)
		MFarmUiArt.place(holder, slot, Vector2(8.5 + (place % BAG_COLUMNS) * 20, 8.5 + (place / BAG_COLUMNS) * 20))
	var head := MFarmUiArt.image(MFarmUiArt.texture("ui_pack_06"), Vector2(16, 16))
	MFarmUiArt.place(_player_bag, head, Vector2(_player_bag.size.x - 18, -2))
	MFarmUiArt.place(head, MFarmUiArt.image(MFarmUiArt.texture("ui_head_01"), Vector2(16, 16)), Vector2.ZERO)
	var coin_holder := MFarmUiArt.image(MFarmUiArt.texture("ui_pack_06"), Vector2(16, 16))
	MFarmUiArt.place(_player_bag, coin_holder, Vector2(2, -2))
	MFarmUiArt.place(coin_holder, MFarmUiArt.image(MFarmUiArt.texture("ui_pack_05"), Vector2(12, 12)), Vector2(2, 2))
	var money_bg := MFarmUiArt.panel("ui_coin_bg", Vector2(40, 12))
	MFarmUiArt.place(_player_bag, money_bg, Vector2(20, 0))
	_money = MFarmUiArt.label("", 8, MFarmUiArt.LIGHT_TEXT_COLOR)
	_money.size = money_bg.size
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_bg.add_child(_money)

func _make_slot(bag_key: StringName, index: int, slot_size := MFarmSlot.SIZE) -> MFarmSlot:
	var slot := MFarmSlot.new(bag_key, index, slot_size)
	slot.menu = self
	slot.hovered.connect(_on_slot_hovered)
	_slots.append(slot)
	return slot

func _refresh_slots(bag_key: StringName) -> void:
	for slot: MFarmSlot in _slots:
		if is_instance_valid(slot) and slot.bag_key == bag_key:
			slot.refresh()

func _on_bag_changed(bag_key: StringName) -> void:
	_refresh_slots(bag_key)

func _on_money_changed(money: int) -> void:
	_money.text = str(money)

func _on_slot_hovered(slot: MFarmSlot, inside: bool) -> void:
	if inside and slot.get_item() != null:
		_tooltip.show_item(slot.get_item(), slot.get_global_rect(), MFarmBagService.is_shop(slot.bag_key))
	else:
		_tooltip.hide_item()
