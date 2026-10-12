class_name HostileCreature
extends CharacterBody2D

## A creature that attacks the player (`EnemyData`): it waits, chases the
## player within its `chase_radius` and strikes their hurtbox (`Hurtbox`) within
## its `attack_range` every `attack_cooldown`, for its `contact_damage`, pushing
## them back. Its own hurtbox takes the player's hits: each flashes it, pushes
## it back and stuns it for `HURT_SECONDS` from that hit. At 0 health it is defeated, drops
## its loot and comes back after `respawn_days`. A `StateMachine` runs it
## (idle, chase, hurt, defeated), and with a `persistent_id` its state saves
## with the world.

const PICKUP_SCENE := preload("res://gamebase/modules/items/items/item_pickup.tscn")
## How long a hit stops it.
const HURT_SECONDS := 0.2

const STATE_IDLE := &"idle"
const STATE_CHASE := &"chase"
const STATE_HURT := &"hurt"
const STATE_DEFEATED := &"defeated"

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
@onready var hurtbox: Hurtbox = $Hurtbox

var health := Health.new()
var is_defeated := false
var defeated_day := 0
var pending_drop_quantity := 0
var _drop_pickup: WorldItemPickup

var _attack_time_left := 0.0
var _hurt_left := 0.0
var _death_time_left := 0.0
var _animation_state := AnimationState.IDLE
var _animation_initialized := false
var _frame_accumulator := 0.0
var _frame_index := 0
var _has_art := false
var _player: Node2D
var _machine := StateMachine.new()

func _ready() -> void:
	_machine.add_state(STATE_IDLE, _idle) \
		.add_state(STATE_CHASE, _chase) \
		.add_state(STATE_HURT, _hurt, _stop) \
		.add_state(STATE_DEFEATED, _rest, _stop)
	_load_state()
	_apply_data()
	hurtbox.hurt.connect(_on_hurt)
	WorldClock.day_changed.connect(_on_day_changed)
	if is_defeated:
		_set_defeated_visual()
		# Nothing of a defeated creature moves until it comes back.
		set_physics_process(false)
		_machine.start(STATE_DEFEATED)
	else:
		# Loading may have set it up as defeated before it came back.
		_set_alive_visual()
		set_physics_process(true)
		_machine.start(STATE_IDLE)
	_refresh_health_label()
	_restore_pending_drop.call_deferred()

func _physics_process(delta: float) -> void:
	_advance_animation(delta)
	if data == null:
		return
	_attack_time_left = maxf(_attack_time_left - delta, 0.0)
	_machine.update(delta)

## The state its `StateMachine` is in: `STATE_IDLE`, `STATE_CHASE`,
## `STATE_HURT` or `STATE_DEFEATED`.
func get_state() -> StringName:
	return _machine.get_state()

func _idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	_set_animation(AnimationState.IDLE)
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= data.chase_radius:
		_machine.change(STATE_CHASE)

func _chase(_delta: float) -> void:
	var player := _find_player()
	if player == null or global_position.distance_to(player.global_position) > data.chase_radius:
		_machine.change(STATE_IDLE)
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	if distance > data.attack_range * 0.65:
		velocity = offset.normalized() * data.move_speed
		move_and_slide()
		_set_animation(AnimationState.MOVE)
		if absf(velocity.x) > 0.1 and _has_art:
			visual.flip_h = velocity.x < 0.0
	else:
		velocity = Vector2.ZERO
		_set_animation(AnimationState.IDLE)
	if distance <= data.attack_range:
		_strike(player, offset)

func _hurt(delta: float) -> void:
	_hurt_left -= delta
	if _hurt_left <= 0.0:
		_machine.change(STATE_CHASE)

func _rest(delta: float) -> void:
	_death_time_left -= delta
	if _death_time_left <= 0.0:
		visual.visible = false
		fallback.visible = false
		set_physics_process(false)

func _stop() -> void:
	velocity = Vector2.ZERO

# Strikes the player's hurtbox; the cooldown starts only with a strike that
# hurt (the player may still be invincible from the last).
func _strike(player: Node2D, offset: Vector2) -> void:
	if _attack_time_left > 0.0 or not PlayerHurtbox.is_standing():
		return
	var target := Hurtbox.of(player)
	var push := offset.normalized() * data.knockback
	if target != null and target.receive(Damage.new(data.contact_damage, data.faction_id, self, push)):
		_attack_time_left = data.attack_cooldown

# The location's player, looked up again only when it left the tree.
func _find_player() -> Node2D:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player

## Takes `amount` of its health without a hit (no flash, stun or
## `CombatEvents.enemy_hurt`); false when it is defeated already or takes
## none. At 0 it is defeated.
func take_damage(amount: int) -> bool:
	if is_defeated or data == null or health.take(amount) <= 0:
		return false
	_persist()
	_refresh_health_label()
	if health.is_depleted():
		_die()
	return true

func get_state_data() -> Dictionary:
	return {
		"health": health.current,
		"defeated": is_defeated,
		"defeated_day": defeated_day,
		"pending_drop_quantity": pending_drop_quantity,
	}

func load_state_data(state: Dictionary, persist := true) -> void:
	var max_health := data.max_health if data != null else 1
	var current_day := maxi(WorldClock.day, 1)
	health.reset(max_health)
	health.current = clampi(SaveValues.whole_number_or(state.get("health", max_health), max_health), 0, max_health)
	var raw_defeated: Variant = state.get("defeated", false)
	is_defeated = raw_defeated is bool and bool(raw_defeated)
	if is_defeated:
		defeated_day = clampi(SaveValues.whole_number_or(state.get("defeated_day", current_day), current_day), 1, current_day)
		health.current = 0
	else:
		defeated_day = 0
		if health.is_depleted():
			health.reset(max_health)
	pending_drop_quantity = SaveValues.count(state.get("pending_drop_quantity", 0))
	# `_ready` sets up a creature that loads as it enters the tree.
	if is_node_ready():
		_death_time_left = 0.0
		if is_defeated:
			_set_defeated_visual()
		else:
			_set_alive_visual()
		_machine.change(STATE_DEFEATED if is_defeated else STATE_IDLE)
		set_physics_process(not is_defeated)
	if persist:
		_persist()
	_refresh_health_label()

func _apply_data() -> void:
	if data == null:
		return
	if health.is_depleted() and not is_defeated:
		health.reset(data.max_health)
	var shape := RectangleShape2D.new()
	shape.size = data.collision_size
	body_shape.shape = shape
	# It is hit where it stands.
	(hurtbox.get_node("CollisionShape2D") as CollisionShape2D).shape = shape
	hurtbox.faction = data.faction_id
	hurtbox.knockback_scale = data.knockback_scale
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
		fallback.color = data.fallback_color

func _on_hurt(damage: Damage) -> void:
	if is_defeated or data == null:
		return
	CombatEvents.enemy_hurt.emit(data.id, mini(damage.amount, health.current))
	take_damage(damage.amount)
	if not is_defeated:
		# A hit while it is still stunned stuns it again from now.
		_hurt_left = HURT_SECONDS
		_machine.change(STATE_HURT)

func _die() -> void:
	is_defeated = true
	defeated_day = WorldClock.day
	collision_layer = 0
	collision_mask = 0
	hurtbox.enabled = false
	_persist()
	_drop_loot()
	CombatEvents.enemy_defeated.emit(data.id, data.combat_xp)
	_set_animation(AnimationState.DEATH)
	_death_time_left = float(data.death_to - data.death_from + 1) / float(maxi(data.animation_fps, 1))
	_machine.change(STATE_DEFEATED)
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
	# A hit can come from a physics callback, where no area may enter the
	# world: the drop lands once the frame's queries are done.
	_restore_pending_drop.call_deferred()

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
	health.reset(data.max_health)
	_set_alive_visual()
	_machine.change(STATE_IDLE)
	set_physics_process(true)
	_persist()
	_refresh_health_label()

func _set_defeated_visual() -> void:
	collision_layer = 0
	collision_mask = 0
	hurtbox.enabled = false
	visual.visible = false
	fallback.visible = false

func _set_alive_visual() -> void:
	collision_layer = 4
	collision_mask = 3
	hurtbox.enabled = true
	visual.visible = _has_art
	fallback.visible = not _has_art
	_set_animation(AnimationState.IDLE)

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

func _advance_animation(delta: float) -> void:
	if not _has_art or data == null or (is_defeated and _death_time_left <= 0.0):
		return
	_frame_accumulator += delta * float(data.animation_fps)
	var frame_range := _get_frame_range_for(_animation_state)
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
		health_label.text = "%s %d/%d" % [tr(data.display_name), health.current, health.maximum]

func _persist() -> void:
	if persistent_id == &"":
		return
	WorldState.set_value(_state_key(), get_state_data())

func _load_state() -> void:
	if data == null:
		return
	health.reset(data.max_health)
	if persistent_id == &"":
		return
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if raw is Dictionary and not raw.is_empty():
		load_state_data(raw, false)
	if is_defeated and WorldClock.day - defeated_day >= data.respawn_days:
		is_defeated = false
		defeated_day = 0
		health.reset(data.max_health)
		_persist()

func _state_key() -> StringName:
	return StringName("enemy:%s" % String(persistent_id))

## The world state the node saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_state_key())]) if persistent_id != &"" else PackedStringArray()
