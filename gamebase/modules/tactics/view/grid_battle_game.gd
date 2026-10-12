class_name GridBattleGame
extends MiniGame

## The tactics module's minigame: the grid battle (`AtbBattle`) of the map its
## settings name (`map`, a `BattleMapData` id), played on a board
## (`GridBattleBoard`) beside the unit whose turn it is and its commands. When
## one of the player's units has its turn, the player moves it, has it take an
## action or ends its turn, picking a cell with the move keys and interact or
## accept, or with the mouse; cancel goes back to the commands. Cancel at the
## commands, pressed twice, gives the battle up. It ends won or lost a moment
## after the battle does (`END_SECONDS`), with the units of the player's side
## left as its score, and tells `TacticsEvents`.

enum Mode {
	## Time passes; no unit of the player's waits for commands.
	WATCH,
	## The player picks a command for the unit whose turn it is.
	COMMAND,
	## The player picks the cell the unit moves to.
	PICK_MOVE,
	## The player picks the cell the unit's action aims at.
	PICK_TARGET,
}

## How long the battle's outcome shows before the minigame ends.
const END_SECONDS := 1.2
const CURSOR_ACTIONS := {
	&"ui_left": Vector2i.LEFT, &"ui_right": Vector2i.RIGHT, &"ui_up": Vector2i.UP, &"ui_down": Vector2i.DOWN,
}
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_accept", &"interact"]

var battle: AtbBattle
var map: BattleMapData

var _mode := Mode.WATCH
var _action: BattleActionData
var _speed := 1.0
var _end_left := 0.0
var _board: GridBattleBoard
var _title: Label
var _info: Label
var _commands: VBoxContainer
var _hint: Label
var _message: Label

func setup(settings: Dictionary) -> void:
	map = BattleMapData.find(StringName(str(settings.get("map", ""))))
	_build()
	if map == null:
		push_warning("GridBattleGame: unknown battle map '%s'" % settings.get("map", ""))
		# Deferred: the host waits for `finished` only once setup returns.
		finish.call_deferred(MiniGameResult.lost(0, {"reason": "unknown map"}))
		return
	var tactics := TacticsSettings.current()
	_speed = tactics.battle_speed
	battle = AtbBattle.from_map(map, tactics)
	battle.turn_started.connect(_on_turn_started)
	battle.unit_moved.connect(_on_unit_moved)
	battle.unit_acted.connect(_on_unit_acted)
	battle.unit_defeated.connect(_on_unit_defeated)
	battle.turn_ended.connect(_on_turn_ended)
	battle.ended.connect(_on_ended)
	_board.show_battle(battle)
	_title.text = tr(map.display_name)
	_set_mode(Mode.WATCH)

func find_settings_problems(settings: Dictionary, registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if settings.has("map") and not registry.has_entry(BattleMapData.KIND, StringName(str(settings["map"]))):
		problems.append("sets unknown battle map '%s'" % settings["map"])
	return problems

## The mode the player is in.
func get_mode() -> Mode:
	return _mode

## The board the battle shows on.
func get_board() -> GridBattleBoard:
	return _board

## Picks the command `index` (as the buttons list them) for the unit whose
## turn it is, as a press of its button does.
func choose_command(index: int) -> void:
	var buttons := _commands.get_children()
	if _mode == Mode.COMMAND and index >= 0 and index < buttons.size():
		var button := buttons[index] as Button
		if not button.disabled:
			button.pressed.emit()

## Picks `cell` in a pick mode, as interact on it does.
func pick(cell: Vector2i) -> void:
	var unit := battle.get_turn_unit() if battle != null else null
	if unit == null or not _board.choices.has(cell):
		return
	if _mode == Mode.PICK_MOVE:
		battle.move(unit, cell)
	elif _mode == Mode.PICK_TARGET:
		battle.act(unit, _action, cell)
	if battle.get_turn_unit() == unit:
		_set_mode(Mode.COMMAND)

func _process(delta: float) -> void:
	if is_finished() or battle == null:
		return
	if battle.is_over():
		_end_left -= delta
		if _end_left <= 0.0:
			var survivors := battle.units.filter(func(unit: GridUnit) -> bool: return unit.is_alive() and battle.is_on_player_side(unit)).size()
			var details := {"map": map.id}
			finish(MiniGameResult.won(survivors, details) if battle.is_won() else MiniGameResult.lost(0, details))
		return
	battle.advance(delta * _speed)

func _unhandled_input(event: InputEvent) -> void:
	if not has_input() or battle == null or battle.is_over():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _mode == Mode.PICK_MOVE or _mode == Mode.PICK_TARGET:
			_set_mode(Mode.COMMAND)
		elif confirm_give_up():
			battle.forfeit()
		else:
			_message.text = get_give_up_prompt()
		return
	if _mode != Mode.PICK_MOVE and _mode != Mode.PICK_TARGET:
		return
	for action: StringName in CURSOR_ACTIONS:
		if event.is_action_pressed(action, true):
			get_viewport().set_input_as_handled()
			_move_cursor(_board.cursor + (CURSOR_ACTIONS[action] as Vector2i))
			return
	for action: StringName in CONFIRM_ACTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			pick(_board.cursor)
			return

func _set_mode(mode: Mode) -> void:
	_mode = mode
	var unit := battle.get_turn_unit() if battle != null else null
	if unit == null and (mode == Mode.COMMAND or mode == Mode.PICK_MOVE or mode == Mode.PICK_TARGET):
		_mode = Mode.WATCH
	_board.turn_unit = unit
	_board.choices.clear()
	_board.reach.clear()
	_board.area.clear()
	_board.show_cursor = _mode == Mode.PICK_MOVE or _mode == Mode.PICK_TARGET
	match _mode:
		Mode.PICK_MOVE:
			_board.choices = battle.get_moves(unit)
			_hint.text = tr("Pick where it moves. Cancel goes back.")
		Mode.PICK_TARGET:
			_board.reach = battle.grid.cells_in_range(unit.cell, _action.min_range, _action.max_range)
			_board.choices = battle.get_targets(unit, _action)
			_hint.text = tr("Pick what it aims at. Cancel goes back.")
		Mode.COMMAND:
			_hint.text = tr("Pick a command.")
		_:
			_hint.text = ""
	if _board.show_cursor:
		_move_cursor(_board.choices[0] if not _board.choices.is_empty() else unit.cell)
	_fill_commands(unit if _mode == Mode.COMMAND else null)
	_show_info()

func _fill_commands(unit: GridUnit) -> void:
	for child: Node in _commands.get_children():
		_commands.remove_child(child)
		child.queue_free()
	if unit == null:
		return
	_add_command(tr("Move"), func() -> void: _set_mode(Mode.PICK_MOVE))
	for action: BattleActionData in unit.data.get_actions():
		_add_command(tr(action.display_name), func() -> void:
			_action = action
			_set_mode(Mode.PICK_TARGET))
	_add_command(tr("End Turn"), func() -> void: battle.end_turn(unit))
	_update_commands(unit)

func _add_command(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(on_pressed)
	_commands.add_child(button)

# Which of the commands `unit` may give now (Move, its actions, End Turn), and
# the focus on one it may.
func _update_commands(unit: GridUnit) -> void:
	var buttons := _commands.get_children()
	var actions := unit.data.get_actions()
	if buttons.size() != actions.size() + 2:
		return
	(buttons[0] as Button).disabled = unit.has_moved or battle.get_moves(unit).is_empty()
	for index in actions.size():
		(buttons[index + 1] as Button).disabled = unit.has_acted or battle.get_targets(unit, actions[index]).is_empty()
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and buttons.has(focused) and not (focused as Button).disabled:
		return
	for child: Node in buttons:
		var button := child as Button
		if not button.disabled:
			button.grab_focus()
			return

# Brings the commands, or the cells to pick, up to date once the battle
# changed while one of the player's units waits (a foe acted meanwhile).
func _refresh() -> void:
	var unit := battle.get_turn_unit()
	if unit == null:
		return
	match _mode:
		Mode.COMMAND:
			_update_commands(unit)
		Mode.PICK_MOVE:
			_board.choices = battle.get_moves(unit)
		Mode.PICK_TARGET:
			_board.reach = battle.grid.cells_in_range(unit.cell, _action.min_range, _action.max_range)
			_board.choices = battle.get_targets(unit, _action)
			_move_cursor(_board.cursor)
	_show_info()

func _move_cursor(cell: Vector2i) -> void:
	if battle == null or not battle.grid.has_cell(cell):
		return
	_board.cursor = cell
	_board.area.clear()
	if _mode == Mode.PICK_TARGET and _board.choices.has(cell):
		_board.area = battle.grid.cells_in_range(cell, 0, _action.area)
	_show_info()

func _show_info() -> void:
	var unit := battle.get_unit_at(_board.cursor) if battle != null and _board.show_cursor else null
	if unit == null and battle != null:
		unit = battle.get_turn_unit()
	if unit == null:
		_info.text = ""
		return
	_info.text = "%s\n%s\n%s" % [
		tr(unit.data.display_name),
		tr("HP %d/%d") % [unit.health.current, unit.health.maximum],
		tr("Attack %d · Defense %d · Move %d") % [unit.data.attack, unit.data.defense, unit.data.move],
	]

func _on_turn_started(unit: GridUnit) -> void:
	if unit.player_controlled:
		_message.text = tr("%s's turn.") % tr(unit.data.display_name)
		_set_mode(Mode.COMMAND)

func _on_unit_moved(unit: GridUnit, _path: Array[Vector2i]) -> void:
	_message.text = tr("%s moves.") % tr(unit.data.display_name)
	_refresh()

func _on_unit_acted(unit: GridUnit, action: BattleActionData, _cell: Vector2i, _hits: Array[Dictionary]) -> void:
	_message.text = tr("%s uses %s.") % [tr(unit.data.display_name), tr(action.display_name)]
	_refresh()

func _on_unit_defeated(unit: GridUnit) -> void:
	_message.text = tr("%s is defeated.") % tr(unit.data.display_name)
	if not battle.is_on_player_side(unit):
		TacticsEvents.foe_defeated.emit(unit.data.id)
	if _board.turn_unit == unit:
		_set_mode(Mode.WATCH)
	else:
		_refresh()

func _on_turn_ended(unit: GridUnit) -> void:
	if unit.player_controlled and battle.get_turn_unit() == null:
		_set_mode(Mode.WATCH)

func _on_ended(won: bool) -> void:
	_end_left = END_SECONDS
	_set_mode(Mode.WATCH)
	_message.text = get_outcome_text(won)
	TacticsEvents.battle_ended.emit(map.id, won)

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(columns)
	_board = GridBattleBoard.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.cell_hovered.connect(func(cell: Vector2i) -> void:
		if _board.show_cursor:
			_move_cursor(cell))
	_board.cell_clicked.connect(func(cell: Vector2i) -> void:
		if has_input() and _board.show_cursor:
			_move_cursor(cell)
			pick(cell))
	columns.add_child(_board)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(132.0, 0.0)
	columns.add_child(side)
	_title = Label.new()
	side.add_child(_title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_info)
	_commands = VBoxContainer.new()
	side.add_child(_commands)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_hint)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_message)
