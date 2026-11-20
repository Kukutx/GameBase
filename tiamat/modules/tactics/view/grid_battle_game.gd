class_name GridBattleGame
extends MiniGame

## The tactics module's minigame: the grid battle (`AtbBattle`) of the map its
## settings name (`map`, a `BattleMapData` id), played on a board
## (`GridBattleBoard`) beside the unit whose turn it is and its commands, which
## scroll when they outgrow a short view, such as a phone's. When
## one of the player's units has its turn, the player moves it, has it take an
## action or ends its turn, picking a cell with the move keys and interact or
## accept, or with the mouse; on a touchscreen a tap on a cell first shows
## what picking it does (where the unit goes, what an action's area covers)
## and a second tap on it picks it, so a finger's slip picks nothing. Once the
## unit has moved, Move becomes Undo Move while the battle lets the player take
## the move back (`AtbBattle.can_undo_move()`), and an action that recharges
## tells in how many turns it is ready (`GridUnit.turns_to_ready()`: "Volley
## (ready in 2)"). While the player picks where
## a unit moves, the board marks the cells the foes could strike next
## (`AtbBattle.get_danger()`), and the side says so of the cell picked, and
## of a cell that gives cover how much less damage a unit there takes, of
## rough ground how many steps it takes to enter, and of a goal cell which
## side wins by ending a turn there (`AtbBattle.goal_cells`); while
## it picks what an action aims at, the side tells what it would do to each
## unit it reaches (`AtbBattle.forecast()`: "Raider takes 6 and falls",
## "Brute takes 2, turn delayed", "Swordsman gains Defense +2", "Knight takes
## 3, Poisoned"), and of a unit the boosts on it and how many turns they hold
## (`GridUnit.get_boost()`), the afflictions on it with the seconds each
## lasts yet (`GridUnit.afflictions`, `Afflictions.describe()`)
## and of a leader that its side flees once it falls (`GridUnit.leader`). The
## board numbers the units whose turns come next
## (`GridBattleBoard.turns_shown`), and the line tells of each unit that
## arrives while the battle runs (`AtbBattle.unit_arrived`) and of each tick
## of an affliction (`AtbBattle.unit_ailed`). With a time limit
## (`AtbBattle.time_limit`), the line says so as the battle starts and the side
## counts down the seconds of battle time left. Cancel (the touch
## controls' corner button on a touchscreen) goes back to the commands.
## Cancel at the commands, pressed twice, gives the battle up. It ends won or
## lost a moment after the battle does (`END_SECONDS`), with the units of the
## player's side left as its score, and tells `TacticsEvents`.
##
## Battle time runs at the game's speed (`TacticsSettings.battle_speed`) times
## the player's choice (`SPEED_OPTION`, which `TacticsModule` declares), read
## as the battle runs, so a change in the settings holds at once. The player's
## foes start with the health the player's foe strength gives them
## (`FOE_STRENGTH_OPTION`), as the battle begins.

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
## The player's option of how fast a grid battle runs (`GameOption`), and how
## much each of its choices speeds the game's speed; a choice not named here
## keeps it.
const SPEED_OPTION := &"grid_battle_speed"
const SPEED_SCALES: Dictionary[String, float] = {"Slow": 0.5, "Standard": 1.0, "Fast": 1.5}
## The player's option of how strong the foes of a grid battle are, and the
## share of their kinds' health each of its choices starts them with; a choice
## not named here starts them with all of it.
const FOE_STRENGTH_OPTION := &"grid_foe_strength"
const FOE_STRENGTH_SCALES: Dictionary[String, float] = {"Weak": 0.75, "Standard": 1.0, "Strong": 1.5}

var battle: AtbBattle
var map: BattleMapData

var _mode := Mode.WATCH
var _action: BattleActionData
var _speed := 1.0
var _end_left := 0.0
var _board: GridBattleBoard
var _title: Label
var _clock: Label
var _info: Label
var _commands: VBoxContainer
var _hint: Label
var _message: Label
# What took a goal, told with the outcome.
var _goal_text := ""

func setup(settings: Dictionary) -> void:
	map = BattleMapData.find(StringName(str(settings.get("map", ""))))
	_build()
	InputPrompts.input_method_changed.connect(_show_hint.unbind(1))
	if map == null:
		push_warning("GridBattleGame: unknown battle map '%s'" % settings.get("map", ""))
		# Deferred: the host waits for `finished` only once setup returns.
		finish.call_deferred(MiniGameResult.lost(0, {"reason": "unknown map"}))
		return
	var tactics := TacticsSettings.current()
	_speed = tactics.battle_speed
	battle = AtbBattle.from_map(map, tactics, GameSettings.options.scale_of(FOE_STRENGTH_OPTION, FOE_STRENGTH_SCALES))
	battle.turn_started.connect(_on_turn_started)
	battle.unit_moved.connect(_on_unit_moved)
	battle.move_undone.connect(_on_move_undone)
	battle.unit_acted.connect(_on_unit_acted)
	battle.unit_defeated.connect(_on_unit_defeated)
	battle.unit_ailed.connect(_on_unit_ailed)
	battle.unit_fled.connect(_on_unit_fled)
	battle.turn_ended.connect(_on_turn_ended)
	battle.goal_taken.connect(_on_goal_taken)
	battle.unit_arrived.connect(_on_unit_arrived)
	battle.ended.connect(_on_ended)
	_board.show_battle(battle)
	_title.text = tr(map.display_name)
	if battle.time_limit != null:
		var line := tr("Hold out for %d seconds of battle.") if battle.time_limit.wins(battle.player_faction) else tr("Win within %d seconds of battle.")
		_message.text = line % roundi(battle.time_limit.seconds)
	_show_clock()
	_set_mode(Mode.WATCH)

func find_settings_problems(settings: Dictionary, registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if settings.has("map") and not registry.has_entry(BattleMapData.KIND, StringName(str(settings["map"]))):
		problems.append("sets unknown battle map '%s'" % settings["map"])
	return problems

## The units the player's side of the map in `settings` can field: its score
## when none falls.
func get_best_possible_score(settings: Dictionary, registry: ContentRegistry) -> int:
	var battle_map := registry.get_entry(BattleMapData.KIND, StringName(str(settings.get("map", "")))) as BattleMapData
	return battle_map.count_player_side() if battle_map != null else -1

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
	battle.advance(delta * get_speed())
	_show_clock()

## How many seconds of battle time pass in a second: the game's battle speed
## at the player's choice (`SPEED_OPTION`).
func get_speed() -> float:
	return _speed * GameSettings.options.scale_of(SPEED_OPTION, SPEED_SCALES)

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
	_board.danger.clear()
	_board.show_cursor = _mode == Mode.PICK_MOVE or _mode == Mode.PICK_TARGET
	match _mode:
		Mode.PICK_MOVE:
			_board.choices = battle.get_moves(unit)
			_board.danger.assign(battle.get_danger(unit).keys())
		Mode.PICK_TARGET:
			_board.reach = battle.grid.cells_in_range(unit.cell, _action.min_range, _action.max_range)
			_board.choices = battle.get_targets(unit, _action)
	_show_hint()
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
	_add_command(tr("Move"), func() -> void:
		if not battle.undo_move(unit):
			_set_mode(Mode.PICK_MOVE))
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

# Which of the commands `unit` may give now (Move or Undo Move, its actions,
# End Turn), and the focus on one it may, Undo Move only when no other is.
func _update_commands(unit: GridUnit) -> void:
	var buttons := _commands.get_children()
	var actions := unit.data.get_actions()
	if buttons.size() != actions.size() + 2:
		return
	var move := buttons[0] as Button
	var undo := battle.can_undo_move(unit)
	move.text = tr("Undo Move") if undo else tr("Move")
	move.disabled = not undo and (unit.has_moved or battle.get_moves(unit).is_empty())
	for index in actions.size():
		var button := buttons[index + 1] as Button
		var action := actions[index]
		var wait := unit.turns_to_ready(action)
		button.text = tr(action.display_name) if wait == 0 else tr("%s (ready in %d)") % [tr(action.display_name), wait]
		button.disabled = unit.has_acted or battle.get_targets(unit, action).is_empty()
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and buttons.has(focused) and not (focused as Button).disabled and not (undo and focused == move):
		return
	for child: Node in buttons:
		var button := child as Button
		if not button.disabled and not (undo and button == move):
			button.grab_focus()
			return
	if undo:
		move.grab_focus()

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
			_board.danger.assign(battle.get_danger(unit).keys())
		Mode.PICK_TARGET:
			_board.reach = battle.grid.cells_in_range(unit.cell, _action.min_range, _action.max_range)
			_board.choices = battle.get_targets(unit, _action)
			_move_cursor(_board.cursor)
	_show_info()

# What the player does now, as the device in use does it.
func _show_hint() -> void:
	var touch := InputPrompts.using_touch
	match _mode:
		Mode.PICK_MOVE:
			_hint.text = tr("Tap where it moves, then tap it again. × goes back.") if touch else tr("Pick where it moves. Cancel goes back.")
		Mode.PICK_TARGET:
			_hint.text = tr("Tap what it aims at, then tap it again. × goes back.") if touch else tr("Pick what it aims at. Cancel goes back.")
		Mode.COMMAND:
			_hint.text = tr("Pick a command.")
		_:
			_hint.text = ""

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
		tr("Attack %d · Defense %d · Move %d") % [unit.get_attack(), unit.get_defense(), unit.data.move],
	]
	var boosts := {GridUnit.ATTACK: unit.get_boost(GridUnit.ATTACK), GridUnit.DEFENSE: unit.get_boost(GridUnit.DEFENSE)}
	if boosts.values().any(func(amount: int) -> bool: return amount != 0):
		_info.text += "\n" + tr("Boosts: %s (turns left: %d)") % [_boost_text(boosts), unit.get_boost_turns()]
	if not unit.afflictions.is_empty():
		_info.text += "\n" + tr("Afflicted: %s") % GameText.list(unit.afflictions.describe())
	if unit.leader:
		_info.text += "\n" + tr("Leader: their side flees when they fall")
	if _board.show_cursor and battle.grid.is_cover(_board.cursor):
		_info.text += "\n" + tr("Cover: %d%% less damage") % roundi(battle.grid.cover_reduction * 100.0)
	if _board.show_cursor and battle.grid.is_rough(_board.cursor):
		_info.text += "\n" + tr("Rough ground: %d steps to enter") % battle.grid.rough_cost
	if _board.show_cursor and battle.goal_cells.has(_board.cursor):
		_info.text += "\n" + (tr("Goal: a foe that ends a turn here wins") if FactionData.are_hostile(battle.goal_faction, battle.player_faction) else tr("Goal: end a turn here to win"))
	if _mode == Mode.PICK_MOVE and _board.danger.has(_board.cursor):
		_info.text += "\n" + tr("Foes can strike here.")
	if _mode == Mode.PICK_TARGET and _board.choices.has(_board.cursor):
		for hit: Dictionary in battle.forecast(battle.get_turn_unit(), _action, _board.cursor):
			var target_name := tr((hit["unit"] as GridUnit).data.display_name)
			var line := tr("%s takes %d")
			if _action.effect == BattleActionData.Effect.HEAL:
				line = tr("%s regains %d")
			elif bool(hit["defeats"]) and (hit["unit"] as GridUnit).leader:
				line = tr("%s takes %d and falls; their side flees")
			elif bool(hit["defeats"]):
				line = tr("%s takes %d and falls")
			elif float(hit.get("delay", 0.0)) > 0.0:
				line = tr("%s takes %d, turn delayed")
			var told := line % [target_name, int(hit["amount"])]
			if hit.has("boosts"):
				var boosted := _boost_text(hit["boosts"])
				told = tr("%s gains %s") % [target_name, boosted] if _action.effect == BattleActionData.Effect.HEAL and int(hit["amount"]) == 0 else GameText.list(PackedStringArray([told, boosted]))
			if hit.has("affliction"):
				told = GameText.list(PackedStringArray([told, tr((hit["affliction"] as AfflictionData).display_name)]))
			if hit.has("cures"):
				var cured := PackedStringArray((hit["cures"] as Array).map(func(affliction: AfflictionData) -> String: return tr(affliction.display_name)))
				told = GameText.list(PackedStringArray([told, tr("cures %s") % GameText.list(cured)]))
			_info.text += "\n" + told

# The boosts in `boosts` (stat -> amount) that change anything, as the player
# reads them: "Attack +2, Defense -1".
func _boost_text(boosts: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat: StringName in [GridUnit.ATTACK, GridUnit.DEFENSE]:
		var amount := int(boosts.get(stat, 0))
		if amount != 0:
			var signed := ("+%d" if amount > 0 else "%d") % amount
			parts.append((tr("Attack %s") if stat == GridUnit.ATTACK else tr("Defense %s")) % signed)
	return GameText.list(parts)

# Counts down the battle time left, with a time limit.
func _show_clock() -> void:
	var limit := battle.time_limit
	_clock.visible = limit != null
	if limit != null:
		_clock.text = (tr("Hold out: %d s") if limit.wins(battle.player_faction) else tr("Time left: %d s")) % ceili(limit.get_left(battle.time))

func _on_turn_started(unit: GridUnit) -> void:
	if unit.player_controlled:
		_message.text = tr("%s's turn.") % tr(unit.data.display_name)
		_set_mode(Mode.COMMAND)

func _on_unit_moved(unit: GridUnit, _path: Array[Vector2i]) -> void:
	_message.text = tr("%s moves.") % tr(unit.data.display_name)
	_refresh()

func _on_move_undone(unit: GridUnit) -> void:
	_message.text = tr("%s steps back.") % tr(unit.data.display_name)
	_refresh()

func _on_unit_acted(unit: GridUnit, action: BattleActionData, _cell: Vector2i, _hits: Array[Dictionary]) -> void:
	_message.text = tr("%s uses %s.") % [tr(unit.data.display_name), tr(action.display_name)]
	_refresh()

func _on_unit_defeated(unit: GridUnit) -> void:
	_message.text = (tr("%s falls, and their side flees!") if unit.leader else tr("%s is defeated.")) % tr(unit.data.display_name)
	if not battle.is_on_player_side(unit):
		TacticsEvents.foe_defeated.emit(unit.data.id)
	if _board.turn_unit == unit:
		_set_mode(Mode.WATCH)
	else:
		_refresh()

func _on_unit_ailed(unit: GridUnit, affliction: AfflictionData, amount: int) -> void:
	_message.text = tr("%s takes %d from %s.") % [tr(unit.data.display_name), amount, tr(affliction.display_name)]
	_refresh()

func _on_unit_arrived(unit: GridUnit) -> void:
	_message.text = (tr("%s joins the battle.") if battle.is_on_player_side(unit) else tr("%s joins the foes!")) % tr(unit.data.display_name)
	_refresh()

func _on_unit_fled(unit: GridUnit) -> void:
	if _board.turn_unit == unit:
		_set_mode(Mode.WATCH)
	else:
		_refresh()

func _on_turn_ended(unit: GridUnit) -> void:
	if unit.player_controlled and battle.get_turn_unit() == null:
		_set_mode(Mode.WATCH)

func _on_goal_taken(unit: GridUnit) -> void:
	_goal_text = tr("%s takes the goal!") % tr(unit.data.display_name)

func _on_ended(won: bool) -> void:
	_end_left = END_SECONDS
	_set_mode(Mode.WATCH)
	if battle.time_limit != null and battle.time_limit.is_up(battle.time) and _goal_text.is_empty():
		_goal_text = tr("Time is up!")
	_message.text = get_outcome_text(won) if _goal_text.is_empty() else "%s %s" % [_goal_text, get_outcome_text(won)]
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
		if not has_input() or not _board.show_cursor:
			return
		var shown := _board.cursor == cell
		_move_cursor(cell)
		if shown or not InputPrompts.using_touch:
			pick(cell))
	columns.add_child(_board)
	# The side scrolls when a unit's commands outgrow a short view (a phone's),
	# so the line under the board stays in view.
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.follow_focus = true
	columns.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(132.0, 0.0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side)
	_title = Label.new()
	side.add_child(_title)
	_clock = Label.new()
	side.add_child(_clock)
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
