class_name MFarmTradePanel
extends NinePatchRect

## Asks how many of a shop's item the player buys, or of their own they sell,
## and makes the trade: a purchase the player cannot pay for, or has no room
## for, does not happen.

var _shop_key := &""
var _index := 0
var _selling := false
var _icon: TextureRect
var _name: Label
var _question: Label
var _amount: LineEdit

func _init() -> void:
	var art := MFarmUiArt.panel("ui_pack_00", Vector2(170, 50))
	texture = art.texture
	patch_margin_left = art.patch_margin_left
	patch_margin_top = art.patch_margin_top
	patch_margin_right = art.patch_margin_right
	patch_margin_bottom = art.patch_margin_bottom
	art.free()
	size = Vector2(170, 50)
	visible = false
	z_index = 5
	var holder := MFarmUiArt.image(MFarmUiArt.texture("ui_slot"), Vector2(40, 40))
	holder.stretch_mode = TextureRect.STRETCH_SCALE
	MFarmUiArt.place(self, holder, Vector2(5, 5))
	_icon = MFarmUiArt.image(null, Vector2(36, 36))
	MFarmUiArt.place(holder, _icon, Vector2(2, 2))
	_name = MFarmUiArt.label("", 8)
	MFarmUiArt.place(self, _name, Vector2(50, 4))
	_question = MFarmUiArt.label("", 8)
	MFarmUiArt.place(self, _question, Vector2(50, 16))
	var field_bg := MFarmUiArt.panel("ui_coin_bg", Vector2(73, 15))
	MFarmUiArt.place(self, field_bg, Vector2(50, 30))
	_amount = LineEdit.new()
	_amount.add_theme_font_override(&"font", MFarmUiArt.FONT)
	_amount.add_theme_font_size_override(&"font_size", 8)
	_amount.add_theme_color_override(&"font_color", MFarmUiArt.LIGHT_TEXT_COLOR)
	_amount.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	_amount.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	_amount.placeholder_text = "How many"
	# A phone shows its number keys for an amount.
	_amount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_amount.size = Vector2(69, 15)
	_amount.position = Vector2(2, 0)
	_amount.text_submitted.connect(func(_text: String) -> void: _submit())
	field_bg.add_child(_amount)
	MFarmUiArt.place(self, _button("ui_check", _submit), Vector2(140, 4))
	MFarmUiArt.place(self, _button("ui_uncheck", close), Vector2(140, 26))

## Asks how many of the item in slot `index` to trade: of the shop's to buy,
## or, `selling`, of the player's bag to sell to the shop.
func open_trade(shop_key: StringName, index: int, selling: bool) -> void:
	var item := MFarmItemData.find(Bags.get_slot(Bags.PLAYER if selling else shop_key, index).item)
	if item == null:
		return
	if selling and item.get_sell_price() <= 0:
		GameEvents.toast("The shop does not buy that")
		return
	_shop_key = shop_key
	_index = index
	_selling = selling
	_icon.texture = item.icon
	_name.text = tr(item.display_name)
	_question.text = tr("How many will you sell?") if selling else tr("How many will you buy?")
	_amount.text = ""
	visible = true
	_amount.grab_focus()

func close() -> void:
	visible = false

func _submit() -> void:
	var amount := _amount.text.to_int()
	if amount <= 0:
		close()
		return
	if _selling:
		if not Bags.sell(_index, amount):
			GameEvents.toast("You do not have that many")
	else:
		var slot := Bags.get_slot(_shop_key, _index)
		var item := MFarmItemData.find(slot.item)
		if item == null or int(slot.amount) < amount:
			GameEvents.toast("The shop does not have that many")
		elif item.price * amount > Bags.money:
			GameEvents.toast("You do not have enough money")
		elif not Bags.buy(_shop_key, _index, amount):
			GameEvents.toast("Your bag is full")
	close()

func _button(art: String, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = MFarmUiArt.texture(art)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.size = Vector2(20, 20)
	button.pressed.connect(action)
	return button
