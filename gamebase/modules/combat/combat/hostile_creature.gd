class_name HostileCreature
extends CharacterBody2D

const PICKUP_SCENE := preload("res://gamebase/modules/items/items/item_pickup.tscn")

enum AnimationState {
	IDLE,
	MOVE,
	DEATH,
}

@export var data: EnemyData
@export var persistent_id: StringName

@onready var visual: Sprite2D = $Visual
@onready var fallback: Polygon2D = $Fallback
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var health_label: Label = $HealthLabel

var health := 1
var is_defeated := false
var defeated_day := 0
var pending_drop_quantity := 0
var _drop_pickup: WorldItemPickup

var _attack_time_left := 0.0
var _death_time_left := 0.0
var _animation_state := AnimationState.IDLE
var _animation_initialized := false
var _frame_accumulator := 0.0
var _frame_index := 0
var _has_art := false

func _ready() -> void:
	_load_state()
	_apply_data()
	WorldClock.day_changed.connect(_on_day_changed)
	if is_defeated:
		_set_defeated_visual()
	else:
		_set_animation(AnimationState.IDLE)
	_refresh_health_label()
	_restore_pending_drop.call_deferred()

func _physics_process(delta: float) -> void:
	_advance_animation(delta)
	if is_defeated:
		if _death_time_left > 0.0:
			_death_time_left -= delta
			if _death_time_left <= 0.0:
				visual.visible = false
				fallback.visible = false
		return
	if data == null:
		return
	_attack_time_left = maxf(_attack_time_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
		_set_animation(AnimationState.IDLE)
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	if distance <= data.chase_radius and distance > data.attack_range * 0.65:
		velocity = offset.normalized() * data.move_speed
		move_and_slide()
		_set_animation(AnimationState.MOVE)
		if absf(velocity.x) > 0.1 and _has_art:
			visual.flip_h = velocity.x < 0.0
	else:
		velocity = Vector2.ZERO
		_set_animation(AnimationState.IDLE)
	if distance <= data.attack_range and _attack_time_left <= 0.0 and PlayerState.health > 0:
		PlayerState.take_damage(data.contact_damage)
		_attack_time_left = data.attack_cooldown

func take_damage(amount: int) -> bool:
	if is_defeated or data == null or amount <= 0:
		return false
	health = maxi(health - amount, 0)
	_persist()
	_refresh_health_label()
	if health <= 0:
		_die()
	return true

func get_state_data() -> Dictionary:
	return {
		"health": health,
		"defeated": is_defeated,
		"defeated_day": defeated_day,
		"pending_drop_quantity": pending_drop_quantity,
	}

func load_state_data(state: Dictionary, persist := true) -> void:
	var max_health := data.max_health if data != null else 1
	var current_day := maxi(WorldClock.day, 1)
	health = clampi(_safe_int(state.get("health", max_health), max_health), 0, max_health)
	var raw_defeated: Variant = state.get("defeated", false)
	is_defeated = raw_defeated is bool and bool(raw_defeated)
	if is_defeated:
		defeated_day = clampi(_safe_int(state.get("defeated_day", current_day), current_day), 1, current_day)
		health = 0
	else:
		defeated_day = 0
		if health <= 0:
			health = max_health
	pending_drop_quantity = maxi(_safe_int(state.get("pending_drop_quantity", 0), 0), 0)
	if persist:
		_persist()
	_refresh_health_label()

func _apply_data() -> void:
	if data == null:
		return
	if health <= 0 and not is_defeated:
		health = data.max_health
	var shape := RectangleShape2D.new()
	shape.size = data.collision_size
	body_shape.shape = shape
	visual.position = data.visual_offset
	visual.scale = Vector2.ONE * data.visual_scale
	_has_art = false
	if not data.sprite_path.is_empty() and ResourceLoader.exists(data.sprite_path):
		var texture := load(data.sprite_path) as Texture2D
		if texture != null:
			visual.texture = texture
			visual.region_enabled = true
			visual.region_filter_clip_enabled = true
			visual.visible = true
			fallback.visible = false
			_has_art = true
	if not _has_art:
		visual.visible = false
		fallback.visible = true

func _die() -> void:
	is_defeated = true
	defeated_day = WorldClock.day
	health = 0
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	_persist()
	_drop_loot()
	CombatEvents.enemy_defeated.emit(data.id, data.combat_xp)
	_set_animation(AnimationState.DEATH)
	_death_time_left = float(data.death_to - data.death_from + 1) / float(maxi(data.animation_fps, 1))
	_refresh_health_label()

func _drop_loot() -> void:
	if data.drop_item_id == &"" or data.drop_quantity <= 0:
		return
	var item := ItemData.find(data.drop_item_id)
	if item == null:
		return
	var remaining := InventoryState.add_item(item, data.drop_quantity)
	if remaining > 0:
		pending_drop_quantity += remaining
		_persist()
	if pending_drop_quantity <= 0 or get_tree().current_scene == null:
		return
	_spawn_drop(item, pending_drop_quantity)

func _spawn_drop(item: ItemData, quantity: int) -> void:
	if quantity <= 0 or get_tree().current_scene == null:
		return
	if is_instance_valid(_drop_pickup):
		_drop_pickup.set_quantity(quantity)
		return
	var pickup := _make_drop_pickup(item, quantity)
	if pickup == null:
		return
	_drop_pickup = pickup
	pickup.items_collected.connect(_on_pending_drop_collected)
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position

func _make_drop_pickup(item: ItemData, quantity: int) -> WorldItemPickup:
	if item == null or quantity <= 0:
		return null
	var pickup := PICKUP_SCENE.instantiate() as WorldItemPickup
	if pickup == null:
		return null
	pickup.item = item
	pickup.quantity = quantity
	pickup.counts_as_forage = false
	return pickup

func _on_pending_drop_collected(_item_id: StringName, _collected: int, remaining: int) -> void:
	pending_drop_quantity = maxi(remaining, 0)
	_persist()
	if pending_drop_quantity <= 0:
		_drop_pickup = null

func _restore_pending_drop() -> void:
	if pending_drop_quantity <= 0 or data == null:
		return
	var item := ItemData.find(data.drop_item_id)
	if item != null:
		_spawn_drop(item, pending_drop_quantity)

func _on_day_changed(day: int) -> void:
	if not is_defeated or data == null:
		return
	if day - defeated_day < data.respawn_days:
		return
	is_defeated = false
	defeated_day = 0
	health = data.max_health
	collision_layer = 4
	collision_mask = 3
	visual.visible = _has_art
	fallback.visible = not _has_art
	_set_animation(AnimationState.IDLE)
	_persist()
	_refresh_health_label()

func _set_defeated_visual() -> void:
	collision_layer = 0
	collision_mask = 0
	visual.visible = false
	fallback.visible = false

func _set_animation(next: AnimationState) -> void:
	if data == null:
		return
	var target_range := _get_frame_range_for(next)
	if _animation_initialized and _animation_state == next and _frame_index >= target_range.x and _frame_index <= target_range.y:
		return
	_animation_state = next
	_animation_initialized = true
	_frame_accumulator = 0.0
	_frame_index = target_range.x
	_update_region()

func _get_frame_range_for(state: AnimationState) -> Vector2i:
	if data == null:
		return Vector2i.ZERO
	match state:
		AnimationState.MOVE:
			return Vector2i(data.move_from, data.move_to)
		AnimationState.DEATH:
			return Vector2i(data.death_from, data.death_to)
		_:
			return Vector2i(data.idle_from, data.idle_to)

func _get_frame_range() -> Vector2i:
	if data == null:
		return Vector2i.ZERO
	match _animation_state:
		AnimationState.MOVE:
			return Vector2i(data.move_from, data.move_to)
		AnimationState.DEATH:
			return Vector2i(data.death_from, data.death_to)
		_:
			return Vector2i(data.idle_from, data.idle_to)

func _advance_animation(delta: float) -> void:
	if not _has_art or data == null or (is_defeated and _death_time_left <= 0.0):
		return
	_frame_accumulator += delta * float(data.animation_fps)
	var frame_range := _get_frame_range()
	while _frame_accumulator >= 1.0:
		_frame_accumulator -= 1.0
		_frame_index += 1
		if _frame_index > frame_range.y:
			_frame_index = frame_range.y if _animation_state == AnimationState.DEATH else frame_range.x
		_update_region()

func _update_region() -> void:
	if not _has_art or visual.texture == null or data == null:
		return
	var columns := maxi(visual.texture.get_width() / maxi(data.frame_size.x, 1), 1)
	var cell := Vector2i(_frame_index % columns, _frame_index / columns)
	visual.region_rect = Rect2(Vector2(cell * data.frame_size), Vector2(data.frame_size))

func _refresh_health_label() -> void:
	if health_label == null:
		return
	health_label.visible = not is_defeated and data != null
	if data != null:
		health_label.text = "%s %d/%d" % [tr(data.display_name), health, data.max_health]

func _persist() -> void:
	if persistent_id == &"":
		return
	WorldState.set_value(_state_key(), get_state_data())

func _load_state() -> void:
	if data == null:
		return
	health = data.max_health
	if persistent_id == &"":
		return
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if raw is Dictionary and not raw.is_empty():
		load_state_data(raw, false)
	if is_defeated and WorldClock.day - defeated_day >= data.respawn_days:
		is_defeated = false
		defeated_day = 0
		health = data.max_health
		_persist()

func _state_key() -> StringName:
	return StringName("enemy:%s" % String(persistent_id))

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

## The world state the node saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_state_key())]) if persistent_id != &"" else PackedStringArray()
