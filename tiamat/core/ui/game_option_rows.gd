class_name GameOptionRows
extends VBoxContainer

## The rows of the settings menu that set the options of the running game
## (`GameSettings.options`, `GameOption`): a switch for an option turned on or
## off, a list for one of a few choices, a slider for a number. Each row
## shows the player's value and sets it as they change it; a game with no
## option shows none.

## How wide a row's name is, as wide as the names of the menu's own rows.
const NAME_WIDTH := 92.0

# The option each row sets, by id: its switch, list or slider.
var _inputs: Dictionary[StringName, Control] = {}

func _ready() -> void:
	for option: GameOption in GameSettings.options.get_declared():
		add_child(_row(option))
	visible = not _inputs.is_empty()
	sync()
	GameSettings.option_changed.connect(_on_option_changed)

## Shows the player's value of every option.
func sync() -> void:
	for id: StringName in _inputs:
		_show(id, GameSettings.get_option(id))

## The switch, list or slider that sets the option `id`, or null.
func get_input(id: StringName) -> Control:
	return _inputs.get(id) as Control

func _row(option: GameOption) -> Control:
	if option.kind == GameOption.Kind.SWITCH:
		var check := CheckButton.new()
		check.text = option.display_name
		check.toggled.connect(_choose.bind(option.id))
		_inputs[option.id] = check
		return check
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = option.display_name
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	row.add_child(label)
	var input: Control
	if option.kind == GameOption.Kind.CHOICE:
		var select := OptionButton.new()
		for choice: String in option.choices:
			select.add_item(choice)
		select.item_selected.connect(func(index: int) -> void: _choose(option.choices[index], option.id))
		input = select
	else:
		var slider := HSlider.new()
		slider.min_value = option.min_value
		slider.max_value = option.max_value
		slider.step = option.step
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_choose.bind(option.id))
		input = slider
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	_inputs[option.id] = input
	return row

func _choose(value: Variant, id: StringName) -> void:
	GameSettings.set_option(id, value)

func _on_option_changed(id: StringName, value: Variant) -> void:
	if _inputs.has(id):
		_show(id, value)

func _show(id: StringName, value: Variant) -> void:
	var input := _inputs[id]
	if input is CheckButton:
		(input as CheckButton).set_pressed_no_signal(bool(value))
	elif input is OptionButton:
		var option := GameSettings.options.find(id)
		(input as OptionButton).select(option.choices.find(str(value)))
	elif input is HSlider:
		(input as HSlider).set_value_no_signal(float(value))
