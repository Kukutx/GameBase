class_name MFarmPlayer
extends TopDownPlayer

## MFarm's farmer: four layers (body, hair, arm, tool), each animated with the
## clips of the item in their hands (carrying, a hoe, a watering can...), the
## item held over their head when they carry it, and the use of that item where
## the cursor points (`use_item`): a tool swings toward it first.

const RUN_SPEED := 100.0
const WALK_SPEED := 50.0
## The old game slowed each axis to 0.6 when walking diagonally (0.6 * √2).
const DIAGONAL_FACTOR := 0.8485281
## How long into a swing the tool works the cell, and how long the swing lasts.
const TOOL_HIT_SECONDS := 0.45
const TOOL_END_SECONDS := 0.25
const HARVEST_SHOW_SECONDS := 1.0
const PARTS: Array[StringName] = [&"Body", &"Hair", &"Arm", &"Tool"]
const LIBRARIES := "res://game/unity/animators/%s.tres"

## What each kind of held item animates the parts with: part -> library name.
## A part not named keeps its plain clips.
const LOOKS := {
	&"none": {},
	&"carry": {&"Arm": "Player/Arm_Hold"},
	&"hoe": {&"Tool": "Tool/Tool_Hoe"},
	&"break": {&"Tool": "Tool/Tool_Break"},
	&"water": {&"Body": "Player/Body_Water", &"Hair": "Player/Hair_Water", &"Arm": "Player/Arm_Water", &"Tool": "Tool/Tool_Water"},
	&"collect": {&"Body": "Player/Body_Collect", &"Hair": "Player/Hair_Collect", &"Arm": "Player/Arm_Collect"},
	&"chop": {&"Tool": "Tool/Tool_Chop"},
	&"reap": {&"Body": "Player/Body_Reap", &"Hair": "Player/Hair_Reap", &"Arm": "Player/Arm_Reap", &"Tool": "Tool/Tool_Reap"},
}
const PLAIN := {&"Body": "Player/Body", &"Hair": "Player/Hair", &"Arm": "Player/Arm", &"Tool": "Tool/Tool"}

@onready var _hold_item: Sprite2D = $Visual/HoldItem

var _look := &""
var _using := false
var _moving := false
var _running := true
var _showing_harvest := 0

func _ready() -> void:
	move_speed = RUN_SPEED
	Bags.selected_changed.connect(_on_selection_changed)
	Bags.bag_changed.connect(_on_bag_changed)
	_on_selection_changed(Bags.selected)

func _physics_process(delta: float) -> void:
	_running = not Input.is_action_pressed(&"walk")
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var diagonal := absf(direction.x) > 0.01 and absf(direction.y) > 0.01
	move_speed = (RUN_SPEED if _running else WALK_SPEED) * (DIAGONAL_FACTOR if diagonal else 1.0)
	super(delta)
	_moving = velocity.length_squared() > 1.0
	if not _using:
		_play_state(("Run" if _running else "Walk") if _moving else "Idle")

func is_input_locked() -> bool:
	return _using or super()

func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return
	for index: int in Bags.ACTION_BAR_SIZE:
		if event.is_action_pressed(StringName("slot_%d" % (index + 1))):
			Bags.select(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"use_item"):
		if use_item(get_global_mouse_position()):
			get_viewport().set_input_as_handled()

## Holds a harvested item over their head for `HARVEST_SHOW_SECONDS`, as the
## old game showed a crop picked with the basket; not while they carry an
## item already.
func show_harvest(item: MFarmItemData) -> void:
	if item == null or _hold_item.visible:
		return
	MFarmSpritePivot.apply(_hold_item, item.get_world_texture())
	_hold_item.visible = true
	_showing_harvest += 1
	await get_tree().create_timer(HARVEST_SHOW_SECONDS).timeout
	_showing_harvest -= 1
	if _showing_harvest == 0 and is_inside_tree():
		_on_selection_changed(Bags.selected)

## Uses the item in the player's hands on the cell under `target`: a seed,
## a harvest or a blueprint at once, a tool after the swing toward it.
func use_item(target: Vector2) -> bool:
	var item := Bags.get_selected_item()
	var grid := get_tree().get_first_node_in_group(&"mfarm_farm_grid") as MFarmFarmGrid
	if item == null or grid == null or not grid.can_use_item(item, target, global_position):
		return false
	if not item.is_tool():
		return grid.use_item(item, target, global_position)
	_swing(item, target, grid)
	return true

func is_using_tool() -> bool:
	return _using

func _swing(item: MFarmItemData, target: Vector2, grid: MFarmFarmGrid) -> void:
	_using = true
	var toward := target - (global_position + Vector2(0, -17))
	face(Vector2(signf(toward.x), 0) if absf(toward.x) > absf(toward.y) else Vector2(0, signf(toward.y)))
	_play_state("Tool")
	await get_tree().create_timer(TOOL_HIT_SECONDS).timeout
	if is_inside_tree():
		grid.use_item(item, target, global_position)
	await get_tree().create_timer(TOOL_END_SECONDS).timeout
	_using = false

func _play_state(state: String) -> void:
	var clip := StringName(state + _direction_name())
	for part: StringName in PARTS:
		var player := get_node(NodePath("Visual/%s/AnimationPlayer" % part)) as AnimationPlayer
		if not player.has_animation(clip):
			continue
		if state == "Tool":
			player.stop()
			player.play(clip)
		elif player.current_animation != clip:
			player.play(clip)

func _direction_name() -> String:
	if absf(facing.x) > absf(facing.y):
		return "Right" if facing.x > 0 else "Left"
	return "Up" if facing.y < 0 else "Down"

func _on_bag_changed(bag_key: StringName) -> void:
	if bag_key == Bags.PLAYER:
		_on_selection_changed(Bags.selected)

func _on_selection_changed(_index: int) -> void:
	var item := Bags.get_selected_item()
	var look := _look_of(item)
	if look == &"carry" and item != null:
		_hold_item.visible = true
		MFarmSpritePivot.apply(_hold_item, item.get_world_texture())
	elif _showing_harvest == 0:
		_hold_item.visible = false
	if look == _look:
		return
	_look = look
	var parts: Dictionary = LOOKS[look]
	for part: StringName in PARTS:
		var player := get_node(NodePath("Visual/%s/AnimationPlayer" % part)) as AnimationPlayer
		var current := player.current_animation
		var library := load(LIBRARIES % String(parts.get(part, PLAIN[part]))) as AnimationLibrary
		if player.has_animation_library(&""):
			player.remove_animation_library(&"")
		player.add_animation_library(&"", library)
		if current != &"" and player.has_animation(current):
			player.play(current)

static func _look_of(item: MFarmItemData) -> StringName:
	if item == null:
		return &"none"
	match item.item_type:
		MFarmItemData.ItemType.SEED, MFarmItemData.ItemType.COMMODITY, MFarmItemData.ItemType.FURNITURE:
			return &"carry"
		MFarmItemData.ItemType.HOE_TOOL:
			return &"hoe"
		MFarmItemData.ItemType.BREAK_TOOL:
			return &"break"
		MFarmItemData.ItemType.WATER_TOOL:
			return &"water"
		MFarmItemData.ItemType.COLLECT_TOOL:
			return &"collect"
		MFarmItemData.ItemType.CHOP_TOOL:
			return &"chop"
		MFarmItemData.ItemType.REAP_TOOL:
			return &"reap"
	return &"none"
