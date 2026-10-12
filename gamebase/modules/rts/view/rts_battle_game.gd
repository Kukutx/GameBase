class_name RtsBattleGame
extends MiniGame

## The rts module's minigame: the command battle (`RtsBattle`) of the map its
## settings name (`map`, an `RtsMapData` id), played on a field
## (`RtsBattleField`) over a bar with the selection and the commands.
##
## With the mouse, a click selects one of the player's units and a dragged box
## selects those in it (Shift adds to the selection, or drops a unit from it);
## a second click on the only unit selected, or a double click, selects every
## unit of its kind. A right click sends the selection after the foe under it,
## else to that place, each unit to its own spot. The commands, on the bar and
## on controls the player can rebind (`COMMAND_ACTIONS`, declared by
## `RtsModule`): Attack-Move (A, then where), Stop (S), Hold (H) and All
## (Tab), or X, LB, Y and RB on a gamepad; Ctrl and a digit keeps the
## selection as a group that the digit selects again. With the keys or a
## gamepad, the arrows
## or the stick move a cursor, and accept or interact at it does what fits:
## selects the player's unit there, or sends the selection there. Cancel drops
## an armed attack-move, then the selection, and pressed twice gives the battle
## up. It ends won or lost a moment after the battle does (`END_SECONDS`), with
## the units of the player's side left as its score, and tells `RtsEvents`.

enum Command {
	## Arms an attack-move: the next click, accept or interact picks where.
	ATTACK_MOVE,
	STOP,
	HOLD,
	## Selects every unit the player orders.
	SELECT_ALL,
}

## How long the battle's outcome shows before the minigame ends.
const END_SECONDS := 1.2
## How far, in pixels of the field, a click may miss a unit and still take it.
const PICK_SLACK := 2.0
## The actions of the commands, in the order of `Command`.
const COMMAND_ACTIONS: Array[StringName] = [&"rts_attack_move", &"rts_stop", &"rts_hold", &"rts_select_all"]
## The keys of the groups, 1 to 9.
const GROUP_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_accept", &"interact"]
## The actions that move the cursor: left, right, up, down.
const DIRECTION_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var battle: RtsBattle
var map: RtsMapData

var _selection: Array[RtsUnit] = []
var _groups: Dictionary[int, Array] = {}
var _armed := false
var _speed := 1.0
var _cursor_speed := 160.0
var _end_left := 0.0
var _field: RtsBattleField
var _info: Label
var _message: Label
var _buttons: Array[Button] = []

func setup(settings: Dictionary) -> void:
	map = RtsMapData.find(StringName(str(settings.get("map", ""))))
	_build()
	if map == null:
		push_warning("RtsBattleGame: unknown command map '%s'" % settings.get("map", ""))
		# Deferred: the host waits for `finished` only once setup returns.
		finish.call_deferred(MiniGameResult.lost(0, {"reason": "unknown map"}))
		return
	var rts := RtsSettings.current()
	_speed = rts.battle_speed
	_cursor_speed = rts.cursor_speed
	battle = RtsBattle.from_map(map)
	battle.unit_defeated.connect(_on_unit_defeated)
	battle.ended.connect(_on_ended)
	_field.show_battle(battle)
	var players := battle.get_player_units()
	if not players.is_empty():
		_field.cursor = players[0].position
	_message.text = tr(map.display_name)
	_show_selection()

func find_settings_problems(settings: Dictionary, registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if settings.has("map") and not registry.has_entry(RtsMapData.KIND, StringName(str(settings["map"]))):
		problems.append("sets unknown command map '%s'" % settings["map"])
	return problems

## The units the player selected.
func get_selection() -> Array[RtsUnit]:
	return _selection.duplicate()

## The field the battle shows on.
func get_field() -> RtsBattleField:
	return _field

## Whether an attack-move waits for the place it goes.
func is_armed() -> bool:
	return _armed

## Selects those of `units` the player orders: in place of the selection, or
## added to it (`additive`).
func select(units: Array[RtsUnit], additive := false) -> void:
	var picked: Array[RtsUnit] = []
	if additive:
		picked.assign(_selection)
	for unit: RtsUnit in units:
		if unit.is_alive() and unit.player_controlled and not picked.has(unit):
			picked.append(unit)
	_set_selection(picked)

## Gives `which`, as its button or its key does.
func command(which: Command) -> void:
	if battle == null or battle.is_over():
		return
	match which:
		Command.ATTACK_MOVE:
			_armed = not _selection.is_empty()
		Command.STOP:
			battle.order_stop(_selection)
		Command.HOLD:
			battle.order_hold(_selection)
		Command.SELECT_ALL:
			select(battle.get_player_units())
	_show_selection()

## What a left click at `point` of the field does: with an attack-move armed,
## sends the selection there fighting; else selects the player's unit there
## (`additive`: adds it, or drops it when selected), every unit of its kind
## (`double`, or a second click on the only unit selected), or nothing.
func click(point: Vector2, additive := false, double := false) -> void:
	if battle == null or battle.is_over():
		return
	if _armed:
		_order(point, true)
		return
	var unit := battle.get_unit_at(point, PICK_SLACK)
	if unit == null or not unit.player_controlled:
		if not additive:
			select([])
		return
	if double or (not additive and _selection.size() == 1 and _selection[0] == unit):
		select(battle.get_player_units().filter(func(other: RtsUnit) -> bool: return other.data == unit.data), additive)
	elif additive and _selection.has(unit):
		var rest := _selection.duplicate()
		rest.erase(unit)
		_set_selection(rest)
	else:
		select([unit] as Array[RtsUnit], additive)

## What a right click at `point` of the field does: sends the selection after
## the foe there, else to that place.
func order(point: Vector2) -> void:
	if battle != null and not battle.is_over() and not _selection.is_empty():
		_order(point, false)

## Selects the player's units in `rect` of the field (`additive`: adds them).
func select_box(rect: Rect2, additive := false) -> void:
	if battle != null and not battle.is_over():
		select(battle.get_units_in(rect), additive)

func _process(delta: float) -> void:
	if is_finished() or battle == null:
		return
	if battle.is_over():
		_end_left -= delta
		if _end_left <= 0.0:
			var survivors := battle.units.filter(func(unit: RtsUnit) -> bool: return unit.is_alive() and battle.is_on_player_side(unit)).size()
			var details := {"map": map.id}
			finish(MiniGameResult.won(survivors, details) if battle.is_won() else MiniGameResult.lost(0, details))
		return
	if has_input():
		var direction := _get_cursor_direction()
		if direction != Vector2.ZERO:
			_field.show_cursor = true
			_field.cursor = (_field.cursor + direction * _cursor_speed * delta).clamp(Vector2.ZERO, battle.size)
	battle.advance(delta * _speed)

# A command comes before the field takes a click, so one the player bound to
# a mouse button works over the field too.
func _input(event: InputEvent) -> void:
	if not has_input() or battle == null or battle.is_over():
		return
	for which: int in COMMAND_ACTIONS.size():
		if InputMap.has_action(COMMAND_ACTIONS[which]) and event.is_action_pressed(COMMAND_ACTIONS[which]):
			get_viewport().set_input_as_handled()
			command(which as Command)
			return

func _unhandled_input(event: InputEvent) -> void:
	if not has_input() or battle == null or battle.is_over():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var group := GROUP_KEYS.find(key.physical_keycode) + 1
		if group > 0:
			get_viewport().set_input_as_handled()
			_use_group(group, key.is_command_or_control_pressed())
			return
	for action: StringName in CONFIRM_ACTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_field.show_cursor = true
			_confirm(_field.cursor)
			return

# Where the arrows, the stick or the pad push the cursor. A command's key
# that also steers, as A and S do where the letters move too, gives its
# command and, while held, moves nothing.
func _get_cursor_direction() -> Vector2:
	for action: StringName in COMMAND_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
			var key := event as InputEventKey
			if key != null and Input.is_physical_key_pressed(key.physical_keycode) and _steers(key):
				return Vector2.ZERO
	return Input.get_vector(DIRECTION_ACTIONS[0], DIRECTION_ACTIONS[1], DIRECTION_ACTIONS[2], DIRECTION_ACTIONS[3])

static func _steers(key: InputEventKey) -> bool:
	return DIRECTION_ACTIONS.any(func(action: StringName) -> bool: return InputMap.has_action(action) and key.is_action(action, true))

func _cancel() -> void:
	if _armed:
		_armed = false
		_show_selection()
	elif not _selection.is_empty():
		select([])
	elif confirm_give_up():
		battle.forfeit()
	else:
		_message.text = get_give_up_prompt()

# Accept or interact at `point`: what fits there.
func _confirm(point: Vector2) -> void:
	var unit := battle.get_unit_at(point, PICK_SLACK)
	if _armed or unit == null or not unit.player_controlled:
		if _armed or not _selection.is_empty():
			_order(point, _armed)
		return
	click(point)

func _order(point: Vector2, attack_move: bool) -> void:
	_armed = false
	var target := battle.get_unit_at(point, PICK_SLACK)
	var attacks := not attack_move and target != null and not battle.is_on_player_side(target)
	if attack_move:
		battle.order_move(_selection, point, true)
	else:
		battle.order_at(_selection, point, PICK_SLACK)
	_field.mark(target.position if attacks else point, attacks or attack_move)
	_show_selection()

func _use_group(group: int, keep: bool) -> void:
	if keep:
		_groups[group] = _selection.duplicate()
		_message.text = tr("Group %d kept.") % group
	elif _groups.has(group):
		var units: Array[RtsUnit] = []
		units.assign(_groups[group])
		select(units)

func _set_selection(units: Array[RtsUnit]) -> void:
	_selection = units
	if _selection.is_empty():
		_armed = false
	_show_selection()

func _show_selection() -> void:
	_field.selection = _selection
	if _armed:
		_info.text = tr("Pick where they attack-move. Cancel drops it.")
	elif _selection.is_empty():
		_info.text = tr("Click or drag a box to select your units.")
	else:
		var counts: Dictionary[RtsUnitData, int] = {}
		for unit: RtsUnit in _selection:
			counts[unit.data] = counts.get(unit.data, 0) + 1
		var kinds := PackedStringArray()
		for data: RtsUnitData in counts:
			kinds.append("%s ×%d" % [tr(data.display_name), counts[data]])
		_info.text = tr("%d selected: %s") % [_selection.size(), ", ".join(kinds)]
	var has_units := battle != null and not battle.get_player_units().is_empty()
	for index in _buttons.size():
		_buttons[index].disabled = not has_units if index == Command.SELECT_ALL else _selection.is_empty()

func _on_unit_defeated(unit: RtsUnit) -> void:
	_message.text = tr("%s falls.") % tr(unit.data.display_name)
	if not battle.is_on_player_side(unit):
		RtsEvents.foe_defeated.emit(unit.data.id)
	if _selection.has(unit):
		_set_selection(_selection.filter(func(other: RtsUnit) -> bool: return other.is_alive()))

func _on_ended(won: bool) -> void:
	_end_left = END_SECONDS
	_armed = false
	_message.text = get_outcome_text(won)
	_show_selection()
	RtsEvents.battle_ended.emit(map.id, won)

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	_field = RtsBattleField.new()
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.clicked.connect(func(point: Vector2, additive: bool, double: bool) -> void:
		if has_input():
			click(point, additive, double))
	_field.box_dragged.connect(func(rect: Rect2, additive: bool) -> void:
		if has_input():
			select_box(rect, additive))
	_field.right_clicked.connect(func(point: Vector2) -> void:
		if has_input():
			order(point))
	rows.add_child(_field)
	var bar := HBoxContainer.new()
	rows.add_child(bar)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.clip_text = true
	bar.add_child(_info)
	for which in COMMAND_ACTIONS.size():
		var button := Button.new()
		# The arrows move the cursor, never the focus.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			if has_input():
				command(which as Command))
		bar.add_child(button)
		_buttons.append(button)
	_show_command_names()
	InputPrompts.input_method_changed.connect(_show_command_names.unbind(1))
	GameSettings.controls_changed.connect(_show_command_names)
	GameSettings.locale_changed.connect(_show_command_names.unbind(1))
	_message = Label.new()
	_message.clip_text = true
	rows.add_child(_message)

# Each command's button names it and its key or button on the device in use.
func _show_command_names() -> void:
	for which: int in _buttons.size():
		var action := COMMAND_ACTIONS[which]
		_buttons[which].text = "%s [%s]" % [GameSettings.bindings.get_label(action), InputPrompts.get_action_prompt(action)]
