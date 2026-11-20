class_name RtsBattleGame
extends MiniGame

## The rts module's minigame: the command battle (`RtsBattle`) of the map its
## settings name (`map`, an `RtsMapData` id), played on a field
## (`RtsBattleField`) over a bar with the selection and the commands; a
## selection of one kind tells what it is strong against
## (`RtsUnitData.strong_against`). On a field with ground to hold
## (`RtsBattle.goal`), the battle's first line says which side wins by holding
## it and how long that takes, and the line tells whenever the side that
## holds it changes. It also tells when units arrive while the battle runs
## (`RtsBattle.unit_arrived`), the player's or their foes'. With a time limit
## (`RtsBattle.time_limit`), the first line says so, unless it tells of ground
## to hold, and the bar counts down the seconds of battle time left.
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
## selects the player's unit there, or sends the selection there. A finger's
## tap does the same where it lands (`tap()`), since a touchscreen has no
## right click: a tap on the player's unit, or within half a fingertip of it
## (`get_pick_slack()`), selects it, a second tap on it
## every unit of its kind, and a tap elsewhere sends the selection there; a
## dragged box selects, and the touch controls' corner button cancels. Cancel drops
## an armed attack-move, then the selection, and pressed twice gives the battle
## up. It ends won or lost a moment after the battle does (`END_SECONDS`), with
## the units of the player's side left as its score, and tells `RtsEvents`.
##
## Battle time runs at the game's speed (`RtsSettings.battle_speed`) times the
## player's choice (`SPEED_OPTION`, which `RtsModule` declares), read as the
## battle runs, so a change in the settings holds at once. The player's foes
## start with the health the player's foe strength gives them
## (`FOE_STRENGTH_OPTION`), as the battle begins.

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
## How much of a fingertip (`TouchTarget.reach`) a finger's tap may miss a
## unit by and still take it: a unit is a few pixels across, far smaller than
## a finger, so a tap takes the nearest unit within half a fingertip.
const TOUCH_PICK_SHARE := 0.5
## The actions of the commands, in the order of `Command`.
const COMMAND_ACTIONS: Array[StringName] = [&"rts_attack_move", &"rts_stop", &"rts_hold", &"rts_select_all"]
## The keys of the groups, 1 to 9.
const GROUP_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_accept", &"interact"]
## The actions that move the cursor: left, right, up, down.
const DIRECTION_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
## The player's option of how fast a command battle runs (`GameOption`), and
## how much each of its choices speeds the game's speed; a choice not named
## here keeps it.
const SPEED_OPTION := &"command_battle_speed"
const SPEED_SCALES: Dictionary[String, float] = {"Slow": 0.5, "Standard": 1.0, "Fast": 1.5}
## The player's option of how strong the foes of a command battle are, and the
## share of their kinds' health each of its choices starts them with; a choice
## not named here starts them with all of it.
const FOE_STRENGTH_OPTION := &"command_foe_strength"
const FOE_STRENGTH_SCALES: Dictionary[String, float] = {"Weak": 0.75, "Standard": 1.0, "Strong": 1.5}

var battle: RtsBattle
var map: RtsMapData

var _selection: Array[RtsUnit] = []
var _groups: Dictionary[int, Array] = {}
var _armed := false
var _speed := 1.0
var _cursor_speed := 160.0
var _end_left := 0.0
var _field: RtsBattleField
var _clock: Label
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
	battle = RtsBattle.from_map(map, GameSettings.options.scale_of(FOE_STRENGTH_OPTION, FOE_STRENGTH_SCALES))
	battle.unit_defeated.connect(_on_unit_defeated)
	battle.ended.connect(_on_ended)
	battle.goal_changed.connect(_on_goal_changed)
	battle.unit_arrived.connect(_on_unit_arrived)
	_field.show_battle(battle)
	var players := battle.get_player_units()
	if not players.is_empty():
		_field.cursor = players[0].position
	_message.text = tr(map.display_name)
	if battle.time_limit != null:
		var limit_line := tr("%s: hold out for %d seconds of battle.") if battle.time_limit.wins(battle.player_faction) else tr("%s: win within %d seconds of battle.")
		_message.text = limit_line % [tr(map.display_name), roundi(battle.time_limit.seconds)]
	_show_clock()
	if battle.goal != null:
		var line := tr("%s: the foes win if they hold the marked ground for %d seconds.") if FactionData.are_hostile(battle.goal.taker, battle.player_faction) else tr("%s: hold the marked ground for %d seconds, or defeat every foe.")
		_message.text = line % [tr(map.display_name), roundi(battle.goal.seconds)]
	_show_selection()

func find_settings_problems(settings: Dictionary, registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if settings.has("map") and not registry.has_entry(RtsMapData.KIND, StringName(str(settings["map"]))):
		problems.append("sets unknown command map '%s'" % settings["map"])
	return problems

## The units the player's side of the map in `settings` can field: its score
## when none falls.
func get_best_possible_score(settings: Dictionary, registry: ContentRegistry) -> int:
	var command_map := registry.get_entry(RtsMapData.KIND, StringName(str(settings.get("map", "")))) as RtsMapData
	return command_map.count_player_side() if command_map != null else -1

## The units the player selected.
func get_selection() -> Array[RtsUnit]:
	return _selection.duplicate()

## How many seconds of battle time pass in a second: the game's battle speed
## at the player's choice (`SPEED_OPTION`).
func get_speed() -> float:
	return _speed * GameSettings.options.scale_of(SPEED_OPTION, SPEED_SCALES)

## The field the battle shows on.
## How far, in pixels of the field, a pick may miss a unit and still take it:
## `PICK_SLACK` for the mouse and the cursor, and on a touchscreen
## `TOUCH_PICK_SHARE` of a fingertip on the screen (`TouchTarget.reach`).
func get_pick_slack() -> float:
	if InputPrompts.using_touch and TouchTarget.reach > 0.0 and _field != null:
		return maxf(PICK_SLACK, TouchTarget.reach * TOUCH_PICK_SHARE / _field.get_zoom())
	return PICK_SLACK

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
	var unit := battle.get_unit_at(point, get_pick_slack())
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

## What a finger's tap at `point` of the field does: what accept does at the
## cursor, selecting the player's unit there (every unit of its kind when it
## is the only one selected), else sending the selection there, after the foe
## there or, with an attack-move armed, fighting on the way.
func tap(point: Vector2) -> void:
	if battle != null and not battle.is_over():
		_confirm(point)

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
			var survivors := battle.get_living_units().filter(func(unit: RtsUnit) -> bool: return battle.is_on_player_side(unit)).size()
			var details := {"map": map.id}
			finish(MiniGameResult.won(survivors, details) if battle.is_won() else MiniGameResult.lost(0, details))
		return
	if has_input():
		var direction := _get_cursor_direction()
		if direction != Vector2.ZERO:
			_field.show_cursor = true
			_field.cursor = (_field.cursor + direction * _cursor_speed * delta).clamp(Vector2.ZERO, battle.size)
	battle.advance(delta * get_speed())
	_show_clock()

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
	var unit := battle.get_unit_at(point, get_pick_slack())
	if _armed or unit == null or not unit.player_controlled:
		if _armed or not _selection.is_empty():
			_order(point, _armed)
		return
	click(point)

func _order(point: Vector2, attack_move: bool) -> void:
	_armed = false
	var target := battle.get_unit_at(point, get_pick_slack())
	var attacks := not attack_move and target != null and not battle.is_on_player_side(target)
	if attack_move:
		battle.order_move(_selection, point, true)
	else:
		battle.order_at(_selection, point, get_pick_slack())
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
		_info.text = tr("%d selected: %s") % [_selection.size(), GameText.list(kinds)]
		if counts.size() == 1:
			var only: RtsUnitData = counts.keys()[0]
			var strong := PackedStringArray()
			for kind: StringName in only.strong_against:
				var other := RtsUnitData.find(kind)
				if other != null:
					strong.append(tr(other.display_name))
			if not strong.is_empty():
				_info.text += " " + tr("(strong against %s)") % GameText.list(strong)
			var affliction := only.get_affliction()
			if affliction != null:
				_info.text += " " + tr("(inflicts %s)") % tr(affliction.display_name)
			if only.cures:
				_info.text += " " + tr("(cures afflictions)")
	var has_units := battle != null and not battle.get_player_units().is_empty()
	for index in _buttons.size():
		_buttons[index].disabled = not has_units if index == Command.SELECT_ALL else _selection.is_empty()

func _on_unit_defeated(unit: RtsUnit) -> void:
	_message.text = tr("%s falls.") % tr(unit.data.display_name)
	if not battle.is_on_player_side(unit):
		RtsEvents.foe_defeated.emit(unit.data.id)
	if _selection.has(unit):
		_set_selection(_selection.filter(func(other: RtsUnit) -> bool: return other.is_alive()))

func _on_goal_changed(holder: RtsUnit) -> void:
	if holder == null:
		_message.text = tr("No one holds the ground.")
	elif battle.is_on_player_side(holder):
		_message.text = tr("Your units hold the ground.")
	else:
		_message.text = tr("The foes hold the ground!")

func _on_unit_arrived(unit: RtsUnit) -> void:
	_message.text = tr("Reinforcements arrive.") if battle.is_on_player_side(unit) else tr("Foe reinforcements arrive!")

# Counts down the battle time left, with a time limit.
func _show_clock() -> void:
	var limit := battle.time_limit
	_clock.visible = limit != null
	if limit != null:
		_clock.text = (tr("Hold out: %d s") if limit.wins(battle.player_faction) else tr("Time left: %d s")) % ceili(limit.get_left(battle.time))

func _on_ended(won: bool) -> void:
	_end_left = END_SECONDS
	_armed = false
	_message.text = get_outcome_text(won)
	if battle.time_limit != null and battle.time_limit.is_up(battle.time):
		_message.text = "%s %s" % [tr("Time is up!"), _message.text]
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
		if not has_input():
			return
		if InputPrompts.using_touch:
			tap(point)
		else:
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
	_clock = Label.new()
	bar.add_child(_clock)
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
		var label := GameSettings.bindings.get_label(action)
		var prompt := InputPrompts.get_action_prompt(action)
		# On a touchscreen the button is the control, named by its label alone.
		_buttons[which].text = label if prompt == label or prompt.is_empty() else "%s [%s]" % [label, prompt]
