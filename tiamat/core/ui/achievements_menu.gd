class_name AchievementsMenu
extends CanvasLayer

## The game's achievements (`AchievementData`) and which the player has
## unlocked (`GameProfile`), from the title or the pause menu, so the player
## sees what is left to reach: how many are unlocked, then each one, those
## unlocked first in the order they were, then those still locked, dimmed. A
## hidden one keeps its name and description to itself until it is unlocked.
## One that counts toward a goal (`AchievementData.progress_flag`) shows how
## far the player is while it is locked, and an achievement's icon shows
## before its name.
## The keys and a gamepad walk through them (`MenuEntry`), the list scrolling
## with them. `ui_cancel` or Back closes it.

signal closed

## The achievements menu's name in `GameEvents.menu_opened` and `menu_closed`.
const MENU_ID := &"achievements_menu"
## How a locked achievement shows.
const LOCKED_TINT := Color(1.0, 1.0, 1.0, 0.5)
## The colour of a description, under the brighter name.
const DESCRIPTION_COLOR := Color(0.76, 0.8, 0.78)
## What a hidden achievement shows until it is unlocked.
const HIDDEN_NAME := "Hidden Achievement"
const HIDDEN_DESCRIPTION := "Unlock it to see what it is."

@onready var _summary: Label = %Summary
@onready var _scroll: ScrollContainer = %Achievements
@onready var _list: VBoxContainer = %List
@onready var _back: Button = %Back

## Whether the running game has any achievement to show.
static func has_any() -> bool:
	return not AchievementData.find_all().is_empty()

## The running game's achievements in the menu's order: the unlocked ones in
## the order they were unlocked, then the locked ones by id.
static func in_order() -> Array[AchievementData]:
	var unlocked: Array[AchievementData] = []
	var locked: Array[AchievementData] = []
	for achievement: AchievementData in AchievementData.find_all():
		(unlocked if GameProfile.is_unlocked(achievement.id) else locked).append(achievement)
	unlocked.sort_custom(func(a: AchievementData, b: AchievementData) -> bool:
		var a_time := GameProfile.get_unlocked_time(a.id)
		var b_time := GameProfile.get_unlocked_time(b.id)
		return a_time < b_time or (a_time == b_time and String(a.id) < String(b.id)))
	unlocked.append_array(locked)
	return unlocked

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_back.pressed.connect(close)
	# Its small print reads on a phone, in a narrow view as in a wide one.
	ReadableText.raise(self)

## Shows the achievements as the profile holds them now.
func open() -> void:
	_fill()
	var opened := not visible
	visible = true
	_scroll.scroll_vertical = 0
	MenuLayer.focus(_list.get_child(0) as Control if _list.get_child_count() > 0 else _back)
	if opened:
		GameEvents.menu_opened.emit(MENU_ID)

func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.menu_closed.emit(MENU_ID)
	closed.emit()

## The line that counts the unlocked achievements.
func get_summary() -> String:
	return _summary.text

## The entries the menu shows, in order: each its name and its description.
func get_entries() -> Array[PackedStringArray]:
	var entries: Array[PackedStringArray] = []
	for entry: Node in _list.get_children():
		entries.append((entry as MenuEntry).get_lines())
	return entries

## How far the player is toward `achievement`, as its entry shows it.
static func progress_text(achievement: AchievementData) -> String:
	return "%d / %d" % [GameProfile.get_progress(achievement.id), achievement.goal]

## The icon of the entry at `index`, or null.
func get_entry_icon(index: int) -> Texture2D:
	return (_list.get_child(index) as MenuEntry).get_icon()

## Whether the entry at `index` shows as locked.
func is_entry_locked(index: int) -> bool:
	return (_list.get_child(index) as CanvasItem).modulate == LOCKED_TINT

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _fill() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var achievements := in_order()
	var unlocked := 0
	for achievement: AchievementData in achievements:
		var is_unlocked := GameProfile.is_unlocked(achievement.id)
		var shown := is_unlocked or not achievement.hidden
		var entry := MenuEntry.new()
		entry.add_line(achievement.display_name if shown else HIDDEN_NAME)
		var about := entry.add_line(achievement.description if shown else HIDDEN_DESCRIPTION)
		about.add_theme_color_override(&"font_color", DESCRIPTION_COLOR)
		if shown and not is_unlocked and achievement.counts_progress():
			var progress := entry.add_line(progress_text(achievement), false)
			progress.add_theme_color_override(&"font_color", DESCRIPTION_COLOR)
		if shown:
			entry.set_icon(achievement.icon)
		if is_unlocked:
			unlocked += 1
		else:
			entry.modulate = LOCKED_TINT
		_list.add_child(entry)
	_summary.text = tr("%d of %d unlocked") % [unlocked, achievements.size()]
	ReadableText.raise(_list)
