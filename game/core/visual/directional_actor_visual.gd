class_name DirectionalActorVisual
extends Node

signal action_started(action: StringName)
signal action_finished(action: StringName)

@export var sprite_frames: SpriteFrames
@export_dir var strip_root: String
@export var strip_frame_size := Vector2i(32, 32)
@export_range(1.0, 30.0, 0.5) var idle_fps := 6.0
@export_range(1.0, 30.0, 0.5) var walk_fps := 10.0
@export_range(1.0, 30.0, 0.5) var action_fps := 12.0
@export var sprite_scale := Vector2.ONE
@export var sprite_offset := Vector2.ZERO
@export var sprite_modulate := Color.WHITE
@export var default_facing := Vector2.DOWN

@export var idle_down: StringName = &"idle_down"
@export var idle_up: StringName = &"idle_up"
@export var idle_left: StringName = &"idle_left"
@export var idle_right: StringName = &"idle_right"
@export var walk_down: StringName = &"walk_down"
@export var walk_up: StringName = &"walk_up"
@export var walk_left: StringName = &"walk_left"
@export var walk_right: StringName = &"walk_right"

var facing := Vector2.DOWN
var _mirror_left := false
var _action_playing := false
var _current_action: StringName

@onready var actor := get_parent() as CharacterBody2D
@onready var sprite := get_node_or_null("Sprite") as AnimatedSprite2D
@onready var fallback_body := actor.get_node_or_null("Body") as CanvasItem if actor != null else null
@onready var fallback_facing := actor.get_node_or_null("Facing") as CanvasItem if actor != null else null

func _ready() -> void:
	facing = default_facing.normalized() if default_facing.length_squared() > 0.0 else Vector2.DOWN
	_apply_parent_profile_presentation()
	if sprite_frames == null and not strip_root.is_empty():
		sprite_frames = _build_frames_from_directional_strips(strip_root)
	if sprite != null:
		if sprite_frames != null:
			sprite.sprite_frames = sprite_frames
		sprite.scale = sprite_scale
		sprite.position = sprite_offset
		sprite.modulate = sprite_modulate
		if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			sprite.animation_finished.connect(_on_sprite_animation_finished)
	_update_visual(Vector2.ZERO)

func _process(_delta: float) -> void:
	if actor == null or _action_playing:
		return
	_update_visual(actor.velocity)

func get_animation_for_velocity(velocity: Vector2) -> StringName:
	var moving := velocity.length_squared() > 0.01
	if moving:
		facing = _cardinal_direction(velocity)
	return _animation_name(facing, moving)

func play_action(action: StringName) -> bool:
	if sprite == null or sprite_frames == null or action == &"":
		return false
	var direction := direction_name(facing)
	var animation := StringName("%s_%s" % [String(action), String(direction)])
	if not sprite_frames.has_animation(animation):
		return false
	_action_playing = true
	_current_action = action
	sprite.visible = true
	sprite.flip_h = _mirror_left and direction == &"left"
	if fallback_body != null:
		fallback_body.visible = false
	if fallback_facing != null:
		fallback_facing.visible = false
	sprite.play(animation)
	action_started.emit(action)
	return true

func is_action_playing() -> bool:
	return _action_playing

static func direction_name(direction: Vector2) -> StringName:
	var normalized := direction.normalized()
	if normalized.length_squared() <= 0.0:
		return &"down"
	if absf(normalized.x) > absf(normalized.y):
		return &"right" if normalized.x > 0.0 else &"left"
	return &"down" if normalized.y > 0.0 else &"up"

func _update_visual(velocity: Vector2) -> void:
	var moving := velocity.length_squared() > 0.01
	if moving:
		facing = _cardinal_direction(velocity)
	var direction := direction_name(facing)
	var animation := _animation_name(facing, moving)
	var has_sprite_animation := sprite != null and sprite_frames != null and sprite_frames.has_animation(animation)
	if sprite != null:
		sprite.visible = has_sprite_animation
		if has_sprite_animation:
			sprite.flip_h = _mirror_left and direction == &"left"
			if sprite.animation != animation or not sprite.is_playing():
				sprite.play(animation)
	if fallback_body != null:
		fallback_body.visible = not has_sprite_animation
	if fallback_facing != null:
		fallback_facing.visible = not has_sprite_animation
		if not has_sprite_animation:
			fallback_facing.rotation = facing.angle() + PI / 2.0

func _apply_parent_profile_presentation() -> void:
	if actor == null:
		return
	var raw_profile: Variant = actor.get("profile")
	if raw_profile is NpcProfileData:
		var profile := raw_profile as NpcProfileData
		if strip_root.is_empty() and not profile.visual_strip_root.is_empty():
			strip_root = profile.visual_strip_root
		sprite_modulate = profile.visual_modulate

func _cardinal_direction(direction: Vector2) -> Vector2:
	match direction_name(direction):
		&"up":
			return Vector2.UP
		&"left":
			return Vector2.LEFT
		&"right":
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

func _animation_name(direction: Vector2, moving: bool) -> StringName:
	match direction_name(direction):
		&"up":
			return walk_up if moving else idle_up
		&"left":
			return walk_left if moving else idle_left
		&"right":
			return walk_right if moving else idle_right
		_:
			return walk_down if moving else idle_down

func _build_frames_from_directional_strips(root: String) -> SpriteFrames:
	if strip_frame_size.x <= 0 or strip_frame_size.y <= 0:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var loaded_any := false
	loaded_any = _add_strip(frames, idle_down, root.path_join("D_Idle.png"), idle_fps, true) or loaded_any
	loaded_any = _add_strip(frames, walk_down, root.path_join("D_Walk.png"), walk_fps, true) or loaded_any
	loaded_any = _add_strip(frames, idle_up, root.path_join("U_Idle.png"), idle_fps, true) or loaded_any
	loaded_any = _add_strip(frames, walk_up, root.path_join("U_Walk.png"), walk_fps, true) or loaded_any

	var side_idle_loaded := _add_strip(frames, idle_right, root.path_join("S_Idle.png"), idle_fps, true)
	var side_walk_loaded := _add_strip(frames, walk_right, root.path_join("S_Walk.png"), walk_fps, true)
	if side_idle_loaded:
		_duplicate_animation(frames, idle_right, idle_left)
	if side_walk_loaded:
		_duplicate_animation(frames, walk_right, walk_left)
	_mirror_left = side_idle_loaded or side_walk_loaded
	loaded_any = loaded_any or side_idle_loaded or side_walk_loaded

	loaded_any = _add_directional_action(frames, root, "Attack", &"attack", action_fps) or loaded_any
	loaded_any = _add_directional_action(frames, root, "Hurt", &"hurt", action_fps) or loaded_any
	loaded_any = _add_directional_action(frames, root, "Death", &"death", maxf(action_fps * 0.75, 1.0)) or loaded_any
	return frames if loaded_any else null

func _add_directional_action(frames: SpriteFrames, root: String, file_suffix: String, action: StringName, fps: float) -> bool:
	var down := StringName("%s_down" % String(action))
	var up := StringName("%s_up" % String(action))
	var right := StringName("%s_right" % String(action))
	var left := StringName("%s_left" % String(action))
	var loaded := false
	loaded = _add_strip(frames, down, root.path_join("D_%s.png" % file_suffix), fps, false) or loaded
	loaded = _add_strip(frames, up, root.path_join("U_%s.png" % file_suffix), fps, false) or loaded
	var side_loaded := _add_strip(frames, right, root.path_join("S_%s.png" % file_suffix), fps, false)
	if side_loaded:
		_duplicate_animation(frames, right, left)
		_mirror_left = true
	loaded = side_loaded or loaded
	return loaded

func _add_strip(frames: SpriteFrames, animation: StringName, path: String, fps: float, loop: bool) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var texture := load(path) as Texture2D
	if texture == null or texture.get_height() < strip_frame_size.y:
		return false
	var frame_count := texture.get_width() / strip_frame_size.x
	if frame_count <= 0:
		return false
	if not frames.has_animation(animation):
		frames.add_animation(animation)
	frames.set_animation_loop(animation, loop)
	frames.set_animation_speed(animation, fps)
	for index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * strip_frame_size.x, 0, strip_frame_size.x, strip_frame_size.y)
		frames.add_frame(animation, atlas)
	return true

func _duplicate_animation(frames: SpriteFrames, source: StringName, target: StringName) -> void:
	if not frames.has_animation(source):
		return
	if not frames.has_animation(target):
		frames.add_animation(target)
	frames.set_animation_loop(target, frames.get_animation_loop(source))
	frames.set_animation_speed(target, frames.get_animation_speed(source))
	for index in range(frames.get_frame_count(source)):
		frames.add_frame(target, frames.get_frame_texture(source, index), frames.get_frame_duration(source, index))

func _on_sprite_animation_finished() -> void:
	if not _action_playing:
		return
	var completed := _current_action
	_action_playing = false
	_current_action = &""
	action_finished.emit(completed)
	_update_visual(actor.velocity if actor != null else Vector2.ZERO)
