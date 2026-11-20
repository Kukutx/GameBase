class_name HostileCreature
extends CharacterBody2D

## A creature that attacks the player (`EnemyData`): it waits, chases the
## player within its `chase_radius` and strikes their hurtbox (`Hurtbox`)
## within its `attack_range` every `attack_cooldown`, for its
## `contact_damage`, pushing them back, or with a `shot_speed` shoots at them
## from there (`CreatureShot`) and backs away from them nearer than
## `SHOT_KEEP_AWAY`. One with a `windup_seconds` first stands and glows that
## long, and strikes only if the player is still in reach. Its own hurtbox
## takes the player's hits: each flashes it, pushes it back and stuns it for
## `HURT_SECONDS` from that hit. At 0 health it is defeated, drops its loot and
## comes back after `respawn_days`. A `StateMachine` runs it (idle, chase,
## windup, hurt, defeated), and with a `persistent_id` its state saves with the
## world. Chasing the player or stunned by their hit, it hunts them, which
## makes a fight (`FightState`). It has the health of its kind times the
## player's foe strength (`STRENGTH_OPTION`, which `CombatModule` declares).
## An `elite` form makes it stronger, larger and tinted, and worth more.

## How long a hit stops it.
const HURT_SECONDS := 0.2
## How far its shots fly (`EnemyData.shot_speed`), in its `attack_range`.
const SHOT_REACH := 1.5
## How near one that shoots lets the player come before it backs away, in its
## `attack_range`.
const SHOT_KEEP_AWAY := 0.4

## The player's option of how strong the creatures are, and the share of
## their kinds' health each of its choices gives them; a choice not named here
## gives them all of it.
const STRENGTH_OPTION := &"foe_strength"
const STRENGTH_SCALES: Dictionary[String, float] = {"Weak": 0.75, "Standard": 1.0, "Strong": 1.5}
const STATE_IDLE := &"idle"
const STATE_CHASE := &"chase"
const STATE_HURT := &"hurt"
const STATE_WINDUP := &"windup"
const STATE_DEFEATED := &"defeated"

enum AnimationState {
	IDLE,
	MOVE,
	DEATH,
}

@export var data: EnemyData
@export var persistent_id: StringName
## The stronger form it takes (`EliteData`), set before it enters the tree;
## null: its kind as it is.
@export var elite: EliteData
## How it glows while it winds up a strike (`EnemyData.windup_seconds`): a
## warm brightening that shows on art of any colour.
@export var windup_color := Color(2.2, 1.9, 1.5)

@onready var visual: Sprite2D = $Visual
@onready var fallback: Polygon2D = $Fallback
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var health_label: Label = $HealthLabel
@onready var hurtbox: Hurtbox = $Hurtbox

var health := Health.new()
var is_defeated := false
var defeated_day := 0
## What it dropped that the player's bag could not hold, waiting where it
## fell.
var drop := OverflowDrop.new()

var _attack_time_left := 0.0
var _hurt_left := 0.0
var _windup_left := 0.0
var _death_time_left := 0.0
# Plays its sheet's frames while it has art.
var _animator: SheetAnimator
var _has_art := false
var _player: Node2D
var _machine := StateMachine.new()

func _ready() -> void:
	_machine.add_state(STATE_IDLE, _idle) \
		.add_state(STATE_CHASE, _chase) \
		.add_state(STATE_HURT, _hurt, _stop) \
		.add_state(STATE_WINDUP, _windup, _start_windup, _end_windup) \
		.add_state(STATE_DEFEATED, _rest, _stop)
	_machine.state_changed.connect(_on_state_changed)
	_load_state()
	_apply_data()
	hurtbox.hurt.connect(_on_hurt)
	drop.changed.connect(_persist)
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
	_show_drop.call_deferred()

func _exit_tree() -> void:
	FightState.set_hunting(self, false)

func _physics_process(delta: float) -> void:
	_advance_animation(delta)
	if data == null:
		return
	_attack_time_left = maxf(_attack_time_left - delta, 0.0)
	_machine.update(delta)

# Chasing the player, or stunned by their hit, it hunts them (`FightState`).
func _on_state_changed(_from: StringName, to: StringName) -> void:
	FightState.set_hunting(self, to == STATE_CHASE or to == STATE_HURT)

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
		_walk(offset, offset)
	elif data.shot_speed > 0.0 and distance < data.attack_range * SHOT_KEEP_AWAY:
		_walk(-offset, offset)
	else:
		velocity = Vector2.ZERO
		_set_animation(AnimationState.IDLE)
	if distance <= data.attack_range:
		if data.windup_seconds <= 0.0:
			_strike(player, offset)
		elif _attack_time_left <= 0.0 and PlayerHurtbox.is_standing():
			_machine.change(STATE_WINDUP)

# Walks along `direction` at its speed, facing along `facing`.
func _walk(direction: Vector2, facing: Vector2) -> void:
	velocity = direction.normalized() * data.move_speed * _elite_scale(&"speed_scale")
	move_and_slide()
	_set_animation(AnimationState.MOVE)
	if absf(facing.x) > 0.1 and _has_art:
		visual.flip_h = facing.x < 0.0

func _start_windup() -> void:
	velocity = Vector2.ZERO
	_windup_left = data.windup_seconds
	_set_animation(AnimationState.IDLE)
	visual.modulate = windup_color
	fallback.modulate = windup_color

# Once wound up it strikes where the player is then, if still in reach; hit or
# missed, the next waits for its cooldown.
func _windup(delta: float) -> void:
	_windup_left -= delta
	if _windup_left > 0.0:
		return
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= data.attack_range:
		_strike(player, player.global_position - global_position)
	_attack_time_left = maxf(_attack_time_left, data.attack_cooldown)
	_machine.change(STATE_CHASE)

func _end_windup() -> void:
	visual.modulate = Color.WHITE
	fallback.modulate = Color.WHITE

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

# Strikes the player's hurtbox, or shoots at them; the cooldown starts only
# with a strike that hurt (the player may still be invincible from the last)
# and with each shot.
func _strike(player: Node2D, offset: Vector2) -> void:
	if _attack_time_left > 0.0 or not PlayerHurtbox.is_standing():
		return
	var push := offset.normalized() * data.knockback
	var hit := Damage.new(roundi(data.contact_damage * _elite_scale(&"damage_scale")), data.faction_id, self, push)
	if data.shot_speed > 0.0:
		CreatureShot.fire(self, player.global_position, data.shot_speed, data.attack_range * SHOT_REACH, hit, data.shot_color)
		_attack_time_left = data.attack_cooldown
		return
	var target := Hurtbox.of(player)
	if target != null and target.receive(hit):
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

## Its full health: its kind's at the player's foe strength, and its elite
## form's share of that.
func get_max_health() -> int:
	return maxi(1, roundi(max_health_of(data) * _elite_scale(&"health_scale"))) if data != null else 1

## Its name as the player reads it: its kind's, in its elite form ("Hulking
## Slime").
func get_display_name() -> String:
	if data == null:
		return ""
	return elite.name_of(data) if elite != null else tr(data.display_name)

# How much of its kind's speed, hit or health (`field`, a scale of
# `EliteData`) it has: all of it without an elite form.
func _elite_scale(field: StringName) -> float:
	return float(elite.get(field)) if elite != null else 1.0

## The full health of kind `enemy` at the player's foe strength.
static func max_health_of(enemy: EnemyData) -> int:
	return maxi(1, roundi(enemy.max_health * GameSettings.options.scale_of(STRENGTH_OPTION, STRENGTH_SCALES)))

func get_state_data() -> Dictionary:
	return {
		"health": health.current,
		"defeated": is_defeated,
		"defeated_day": defeated_day,
		"pending_drop_quantity": drop.quantity,
	}

func load_state_data(state: Dictionary, persist := true) -> void:
	var max_health := get_max_health()
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
	drop.load_count(state.get("pending_drop_quantity", 0))
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
		health.reset(get_max_health())
	var size := _elite_scale(&"size_scale")
	var tint := elite.tint if elite != null else Color.WHITE
	var shape := RectangleShape2D.new()
	shape.size = data.collision_size * size
	body_shape.shape = shape
	# It is hit where it stands.
	(hurtbox.get_node("CollisionShape2D") as CollisionShape2D).shape = shape
	hurtbox.faction = data.faction_id
	hurtbox.knockback_scale = data.knockback_scale
	visual.position = data.visual_offset * size
	visual.scale = Vector2.ONE * data.visual_scale * size
	_has_art = false
	if not data.sprite_path.is_empty() and ResourceLoader.exists(data.sprite_path):
		var texture := load(data.sprite_path) as Texture2D
		if texture != null:
			visual.texture = texture
			# Its own colours, so the hit flash (`Hurtbox`) still tints it all.
			visual.self_modulate = data.sprite_tint * tint
			visual.region_enabled = true
			visual.region_filter_clip_enabled = true
			visual.visible = true
			fallback.visible = false
			_has_art = true
	_animator = SheetAnimator.new(visual, data.frame_size, data.animation_fps) if _has_art else null
	if not _has_art:
		visual.visible = false
		fallback.visible = true
		fallback.color = data.fallback_color * tint

func _on_hurt(damage: Damage) -> void:
	if is_defeated or data == null:
		return
	CombatEvents.enemy_hurt.emit(data.id, mini(damage.amount, health.current), global_position)
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
	CombatEvents.enemy_defeated.emit(data.id, roundi(data.combat_xp * _elite_scale(&"xp_scale")), global_position)
	if elite != null:
		CombatEvents.elite_defeated.emit(elite.id, data.id, global_position)
	_set_animation(AnimationState.DEATH)
	_death_time_left = float(data.death_to - data.death_from + 1) / float(maxi(data.animation_fps, 1))
	_machine.change(STATE_DEFEATED)
	_refresh_health_label()

## How many of its drop it leaves now: `EnemyData.drop_quantity` (and an
## elite form's `extra_drops`) changed by the loot stat
## (`PlayerHurtbox.LOOT_STAT`), its fraction rounded by chance (a stream of the
## creature and the minute it fell).
func get_drop_quantity() -> int:
	var quantity := GameStats.apply(PlayerHurtbox.LOOT_STAT, data.drop_quantity + (elite.extra_drops if elite != null else 0))
	var rolls := GameRandom.stream("loot:%s:%d" % [get_path(), WorldClock.get_absolute_minute()])
	return rolls.round_by_chance(quantity)

func _drop_loot() -> void:
	if data.drop_item_id == &"" or data.drop_quantity <= 0:
		return
	drop.give(ItemData.find(data.drop_item_id), get_drop_quantity())
	# A hit can come from a physics callback, where no area may enter the
	# world: the drop lands once the frame's queries are done.
	_show_drop.call_deferred()

func _show_drop() -> void:
	if data != null and drop.quantity > 0:
		drop.show(self, ItemData.find(data.drop_item_id))

func _on_day_changed(day: int) -> void:
	if not is_defeated or data == null:
		return
	if day - defeated_day < data.respawn_days:
		return
	is_defeated = false
	defeated_day = 0
	health.reset(get_max_health())
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
	if _animator != null:
		_animator.play(_get_frame_range_for(next), next != AnimationState.DEATH)

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
	# A fallen creature's last frame stays until it is hidden.
	if _animator != null and not (is_defeated and _death_time_left <= 0.0):
		_animator.advance(delta)

func _refresh_health_label() -> void:
	if health_label == null:
		return
	health_label.visible = not is_defeated and data != null
	if data != null:
		health_label.text = "%s %d/%d" % [get_display_name(), health.current, health.maximum]

func _persist() -> void:
	if persistent_id == &"":
		return
	WorldState.set_value(_state_key(), get_state_data())

func _load_state() -> void:
	if data == null:
		return
	health.reset(get_max_health())
	if persistent_id == &"":
		return
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if raw is Dictionary and not raw.is_empty():
		load_state_data(raw, false)
	if is_defeated and WorldClock.day - defeated_day >= data.respawn_days:
		is_defeated = false
		defeated_day = 0
		health.reset(get_max_health())
		_persist()

func _state_key() -> StringName:
	return state_key_of(persistent_id)

## The `WorldState` key a creature saved under `id` keeps its state at.
static func state_key_of(id: StringName) -> StringName:
	return StringName("enemy:%s" % String(id))

## Whether the creature of `data` saved under `id` lies defeated, not back yet
## (`EnemyData.respawn_days`): a place tells it before its scene loads, as the
## mine's elevator names the guardians still standing on its stops.
static func is_down(id: StringName, data: EnemyData) -> bool:
	if id == &"" or data == null:
		return false
	var raw: Variant = WorldState.get_value(state_key_of(id), {})
	if not raw is Dictionary or not bool((raw as Dictionary).get("defeated", false)):
		return false
	var defeated_day := SaveValues.whole_number_or((raw as Dictionary).get("defeated_day", WorldClock.day), WorldClock.day)
	return WorldClock.day - defeated_day < data.respawn_days

## The world state the node saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_state_key())]) if persistent_id != &"" else PackedStringArray()
