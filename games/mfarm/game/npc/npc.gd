class_name MFarmNpc
extends Node2D

## A townsperson in the location the player is in. They stand where their
## schedule last sent them and, when the next entry of their day starts, walk
## there cell by cell around what blocks them (never cutting a blocked corner).
## Once there they face the player's way, play their pause animation every
## few seconds, and, where the entry lets them, talk: a mark over their head
## shows the player can, Space starts the conversation, and one with a shop
## opens it once the last line is read.

const PAUSE_BREAK_SECONDS := 5.0
const TALK_DISTANCE := 26.0
const SIGN_LIBRARY: AnimationLibrary = preload("res://game/unity/animators/UI/UI_Sign.tres")
const EXTRA := &"extra"

var data: MFarmNpcData

var _body: Sprite2D
var _animation: AnimationPlayer
var _sign: Sprite2D
var _interactable: Interactable
var _map: MFarmMapData
var _astar: AStarGrid2D
var _path: Array[Vector2i] = []
var _cell := Vector2i.ZERO
var _entry: MFarmScheduleEntry
var _facing := Vector2.DOWN
var _pause_timer := 0.0
var _talking := false
var _clips: Dictionary = {}

## Sets up `npc` standing where their schedule puts them at this time.
func setup(npc: MFarmNpcData, map: MFarmMapData) -> void:
	data = npc
	_map = map
	name = String(npc.id)

func _ready() -> void:
	_build()
	_build_grid()
	_entry = data.get_entry_at(WorldClock.minute_of_day)
	_cell = _entry.cell if _entry != null else data.start_cell
	position = MFarmMapData.cell_center(_cell)
	_play_idle()
	WorldClock.minute_changed.connect(_on_minute_changed)

func is_moving() -> bool:
	return not _path.is_empty()

func can_talk() -> bool:
	return not is_moving() and not _talking and (_entry == null or _entry.interactable) and not data.dialogue.is_empty()

func get_cell() -> Vector2i:
	return _cell

## Starts walking to `target`; with no way there they step straight onto it.
func walk_to(target: Vector2i) -> void:
	_path.clear()
	if target == _cell:
		return
	if _astar != null and _astar.is_in_boundsv(_cell) and _astar.is_in_boundsv(target):
		var points := _astar.get_id_path(_cell, target, true)
		for index: int in range(1, points.size()):
			_path.append(points[index])
		if not _path.is_empty() and _path[-1] != target:
			_path.clear()
	if _path.is_empty():
		_cell = target
		position = MFarmMapData.cell_center(target)
		_play_idle()

func _process(delta: float) -> void:
	if not _path.is_empty():
		_step(delta)
	elif not _talking:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_pause_timer = PAUSE_BREAK_SECONDS
			_play_pause_animation()
	_sign.visible = can_talk() and _player_near()
	_interactable.enabled = can_talk()

func _step(delta: float) -> void:
	var target := MFarmMapData.cell_center(_path[0])
	var offset := target - position
	var distance := data.walk_speed * delta
	if offset.length() <= distance:
		position = target
		_cell = _path.pop_front()
		if _path.is_empty():
			_facing = Vector2.DOWN
			_pause_timer = 0.0
			_play_idle()
		return
	_facing = offset.normalized()
	position += _facing * distance
	_play(data.get_clip("Walk", _direction_name()))

func _play_idle() -> void:
	_play(data.get_clip("Idle", _direction_name()))

func _play_pause_animation() -> void:
	var stop := _entry.stop_animation if _entry != null else &""
	if stop == &"":
		_play_idle()
		return
	_facing = Vector2.DOWN
	var clip := stop if _animation.has_animation(stop) else StringName("%s/%s" % [EXTRA, stop])
	if _animation.has_animation(clip):
		_animation.stop()
		_animation.play(clip)
		_animation.queue(_find_clip(data.get_clip("Idle", "Down")))

func _play(clip: StringName) -> void:
	var found := _find_clip(clip)
	if found != &"" and _animation.current_animation != found:
		_animation.play(found)

# The clip of that name in the NPC's animations, matched without regard to
# case: the old project named one of the mayor's clips "WalkRIght".
func _find_clip(clip: StringName) -> StringName:
	if _clips.has(clip):
		return _clips[clip]
	var found := &""
	for candidate: StringName in _animation.get_animation_list():
		if String(candidate).to_lower() == String(clip).to_lower():
			found = candidate
			break
	_clips[clip] = found
	return found

func _direction_name() -> String:
	if absf(_facing.x) > absf(_facing.y):
		return "Right" if _facing.x > 0 else "Left"
	return "Up" if _facing.y < 0 else "Down"

func _player_near() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	return player != null and player.global_position.distance_to(global_position) <= TALK_DISTANCE

func _on_minute_changed(_day: int, minute_of_day: int) -> void:
	for entry: MFarmScheduleEntry in data.schedule:
		if entry.get_minute_of_day() == minute_of_day:
			_entry = entry
			walk_to(entry.cell)
			return

func _on_interacted(actor: Node) -> void:
	if not can_talk():
		return
	var box := get_tree().get_first_node_in_group(&"mfarm_dialogue_box") as MFarmDialogueBox
	if box == null:
		return
	var player := actor as Node2D
	if player != null:
		var toward := player.global_position - global_position
		_facing = Vector2(signf(toward.x), 0) if absf(toward.x) > absf(toward.y) else Vector2(0, signf(toward.y))
		_play_idle()
	_talking = true
	box.play(data.dialogue)
	await box.finished
	_talking = false
	_pause_timer = PAUSE_BREAK_SECONDS
	if data.shop_bag_id != &"" and is_inside_tree():
		var menu := get_tree().get_first_node_in_group(&"mfarm_bag_menu")
		if menu != null:
			menu.call(&"open_shop", StringName("shop:%s" % data.id), data.shop_bag_id)

func _build() -> void:
	y_sort_enabled = true
	if data.shadow != null:
		var shadow := Sprite2D.new()
		shadow.name = "Shadow"
		MFarmSpritePivot.apply(shadow, data.shadow)
		add_child(shadow)
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.centered = false
	add_child(_body)
	_animation = AnimationPlayer.new()
	_animation.name = "AnimationPlayer"
	_body.add_child(_animation)
	_animation.root_node = ^".."
	_animation.add_animation_library(&"", data.animations)
	if data.extra_animations != null:
		_animation.add_animation_library(EXTRA, data.extra_animations)
	_sign = Sprite2D.new()
	_sign.name = "Sign"
	_sign.centered = false
	_sign.position = Vector2(0, -36)
	_sign.visible = false
	add_child(_sign)
	var sign_animation := AnimationPlayer.new()
	_sign.add_child(sign_animation)
	sign_animation.root_node = ^".."
	sign_animation.add_animation_library(&"", SIGN_LIBRARY)
	sign_animation.play(&"ui_spacebar")
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	_interactable.set_prompt("Talk to %s", [data.display_name])
	_interactable.collision_layer = 16
	_interactable.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 12)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	_interactable.add_child(shape)
	add_child(_interactable)
	_interactable.interacted.connect(_on_interacted)

func _build_grid() -> void:
	if _map == null:
		return
	_astar = AStarGrid2D.new()
	_astar.region = _map.get_grid_rect()
	_astar.cell_size = Vector2.ONE * MFarmMapData.CELL_SIZE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for cell: Vector2i in _map.npc_obstacle:
		if _astar.is_in_boundsv(cell):
			_astar.set_point_solid(cell)
