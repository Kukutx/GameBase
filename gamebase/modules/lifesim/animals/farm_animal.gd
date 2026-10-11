class_name FarmAnimal
extends CharacterBody2D

signal happiness_changed(value: int)
signal product_collected(item_id: StringName, quantity: int)

enum Behavior {
	IDLE,
	WALK,
	EAT,
}

@export var data: FarmAnimalData
@export var persistent_id: StringName
@export var custom_name: String

@onready var visual: Sprite2D = $Visual
@onready var fallback: Polygon2D = $Fallback
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var interactable: Interactable = $Interactable
@onready var name_label: Label = $NameLabel

var happiness := 50
var last_product_day := 0
var last_pet_day := 0
var last_fed_day := 0
var last_processed_day := 0

var _behavior := Behavior.IDLE
var _behavior_time_left := 0.0
var _frame_accumulator := 0.0
var _frame_index := 0
var _home_position := Vector2.ZERO
var _walk_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _has_art := false
var _interaction_busy := false

func _ready() -> void:
	_home_position = global_position
	_rng.seed = GameRandom.seed_for("animal:%s" % persistent_id)
	_load_state()
	if last_processed_day <= 0:
		last_processed_day = WorldClock.day
	elif last_processed_day < WorldClock.day:
		_advance_to_day(WorldClock.day)
	_apply_data()
	interactable.interacted.connect(_on_interacted)
	WorldClock.day_changed.connect(_on_day_changed)
	AnimalState.animal_fed.connect(_on_animal_fed)
	_set_behavior(Behavior.IDLE)
	_refresh_prompt()

func _physics_process(delta: float) -> void:
	if data == null:
		velocity = Vector2.ZERO
		return

	_behavior_time_left -= delta
	match _behavior:
		Behavior.WALK:
			var offset := _walk_target - global_position
			if offset.length() <= 3.0:
				global_position = _walk_target
				velocity = Vector2.ZERO
				_choose_next_behavior()
			else:
				velocity = offset.normalized() * data.move_speed
				move_and_slide()
				if absf(velocity.x) > 0.1 and _has_art:
					visual.flip_h = velocity.x < 0.0
		Behavior.IDLE, Behavior.EAT:
			velocity = Vector2.ZERO

	if _behavior_time_left <= 0.0:
		_choose_next_behavior()
	_advance_animation(delta)

func is_product_ready() -> bool:
	if data == null or data.product_item_id == &"" or not is_fed_today():
		return false
	return WorldClock.day - last_product_day >= data.product_interval_days

func is_fed_today() -> bool:
	return data == null or data.feed_item_id == &"" or last_fed_day >= WorldClock.day

func can_pet_today() -> bool:
	return last_pet_day != WorldClock.day

func get_state_data() -> Dictionary:
	return {
		"happiness": happiness,
		"last_product_day": last_product_day,
		"last_pet_day": last_pet_day,
		"last_fed_day": last_fed_day,
		"last_processed_day": last_processed_day,
	}

func load_state_data(state: Dictionary, persist := true) -> void:
	happiness = clampi(_safe_int(state.get("happiness", 50), 50), 0, 100)
	var current_day := maxi(WorldClock.day, 1)
	var product_interval := maxi(data.product_interval_days if data != null else 1, 1)
	last_product_day = clampi(_safe_int(state.get("last_product_day", current_day - product_interval), current_day - product_interval), current_day - product_interval, current_day)
	last_pet_day = clampi(_safe_int(state.get("last_pet_day", current_day), current_day), 0, current_day)
	last_fed_day = clampi(_safe_int(state.get("last_fed_day", current_day), current_day), 0, current_day)
	last_processed_day = clampi(_safe_int(state.get("last_processed_day", current_day), current_day), 1, current_day)
	if persist:
		_persist()
	_refresh_prompt()

func _apply_data() -> void:
	if data == null:
		name_label.text = tr("Animal")
		return
	name_label.text = get_display_name()
	var rectangle := RectangleShape2D.new()
	rectangle.size = data.collision_size
	body_shape.shape = rectangle
	var interaction_shape := CircleShape2D.new()
	interaction_shape.radius = maxf(data.collision_size.x, data.collision_size.y) * 0.9 + 6.0
	($Interactable/CollisionShape2D as CollisionShape2D).shape = interaction_shape
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
		var half := data.collision_size * 0.7
		fallback.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])

func set_custom_name(value: String) -> void:
	custom_name = value.strip_edges()
	if name_label != null and data != null:
		name_label.text = get_display_name()
	_refresh_prompt()

func get_display_name() -> String:
	if not custom_name.is_empty():
		return custom_name
	return data.display_name if data != null else "Animal"

func _choose_next_behavior() -> void:
	var roll := _rng.randf()
	if roll < 0.34:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(data.wander_radius * 0.25, data.wander_radius)
		_walk_target = _home_position + Vector2.from_angle(angle) * distance
		_set_behavior(Behavior.WALK)
	elif roll < 0.64:
		_set_behavior(Behavior.EAT)
	else:
		_set_behavior(Behavior.IDLE)

func _set_behavior(next: Behavior) -> void:
	_behavior = next
	_behavior_time_left = _rng.randf_range(1.5, 4.2)
	_frame_accumulator = 0.0
	var frame_range := _get_frame_range()
	_frame_index = frame_range.x
	_update_region()

func _get_frame_range() -> Vector2i:
	if data == null:
		return Vector2i.ZERO
	match _behavior:
		Behavior.WALK:
			return Vector2i(data.walk_from, data.walk_to)
		Behavior.EAT:
			return Vector2i(data.eat_from, data.eat_to)
		_:
			return Vector2i(data.idle_from, data.idle_to)

func _advance_animation(delta: float) -> void:
	if not _has_art or data == null:
		return
	_frame_accumulator += delta * float(data.animation_fps)
	var frame_range := _get_frame_range()
	while _frame_accumulator >= 1.0:
		_frame_accumulator -= 1.0
		_frame_index += 1
		if _frame_index > frame_range.y:
			_frame_index = frame_range.x
		_update_region()

func _update_region() -> void:
	if not _has_art or data == null or visual.texture == null:
		return
	var columns := maxi(visual.texture.get_width() / maxi(data.frame_size.x, 1), 1)
	var cell := Vector2i(_frame_index % columns, _frame_index / columns)
	visual.region_rect = Rect2(Vector2(cell * data.frame_size), Vector2(data.frame_size))

func _on_interacted(actor: Node) -> void:
	if _interaction_busy:
		return
	_interaction_busy = true
	_handle_interaction(actor)
	_interaction_busy = false

func _handle_interaction(_actor: Node) -> void:
	if data == null:
		return
	if is_product_ready():
		_collect_product()
		return
	if can_pet_today():
		last_pet_day = WorldClock.day
		happiness = clampi(happiness + data.pet_happiness_gain, 0, 100)
		_persist()
		happiness_changed.emit(happiness)
		GameEvents.toastf("Petted %s · Happiness %d", [get_display_name(), happiness])
		_refresh_prompt()
		return
	GameEvents.toastf("%s looks content", [get_display_name()])

func _collect_product() -> void:
	var product := ItemData.find(data.get_product_item_id(happiness))
	if product == null:
		return
	if not InventoryState.can_add_item(product, data.product_quantity):
		GameEvents.toast("Make room for the full animal product")
		return
	if InventoryState.add_item(product, data.product_quantity) > 0:
		return
	var collected := data.product_quantity
	last_product_day = WorldClock.day
	_persist()
	product_collected.emit(product.id, collected)
	LifesimEvents.animal_product_collected.emit(data.id, product.id, collected)
	GameEvents.toastf("Collected %s x%d", [product.display_name, collected])
	_refresh_prompt()

func _on_day_changed(day: int) -> void:
	_advance_to_day(day)

func _advance_to_day(target_day: int) -> void:
	var resolved_target := maxi(target_day, 1)
	if last_processed_day <= 0:
		last_processed_day = resolved_target
	if last_processed_day < resolved_target:
		var first_previous_day := last_processed_day
		var missed_pet_days := maxi(resolved_target - maxi(first_previous_day, last_pet_day + 1), 0)
		var missed_feed_days := 0
		if data != null and data.feed_item_id != &"":
			missed_feed_days = maxi(resolved_target - maxi(first_previous_day, last_fed_day + 1), 0)
		var total_loss := missed_pet_days + missed_feed_days * (data.missed_feed_happiness_loss if data != null else 0)
		# Commit the full catch-up range before happiness_changed. A listener may
		# advance the clock synchronously; nested catch-up then starts strictly after
		# this range instead of replaying any missed-care day.
		last_processed_day = resolved_target
		if total_loss > 0:
			var next_happiness := maxi(happiness - total_loss, 0)
			if next_happiness != happiness:
				happiness = next_happiness
				happiness_changed.emit(happiness)
	_persist()
	_refresh_prompt()

func _on_animal_fed(instance_id: StringName) -> void:
	if instance_id != persistent_id:
		return
	last_fed_day = WorldClock.day
	_refresh_prompt()

func _refresh_prompt() -> void:
	if interactable == null or data == null:
		return
	if not is_fed_today():
		interactable.set_prompt("%s needs feed", [get_display_name()])
	elif is_product_ready():
		var product := ItemData.find(data.get_product_item_id(happiness))
		interactable.set_prompt("Collect %s", [product.display_name if product != null else "product"])
	elif can_pet_today():
		interactable.set_prompt("Pet %s", [get_display_name()])
	else:
		interactable.set_prompt("%s", [get_display_name()])

func _persist() -> void:
	if persistent_id == &"":
		return
	WorldState.set_value(_state_key(), get_state_data())

func _load_state() -> void:
	if persistent_id == &"":
		return
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if raw is Dictionary and not raw.is_empty():
		load_state_data(raw, false)
	elif data != null:
		last_product_day = WorldClock.day - data.product_interval_days
		last_fed_day = WorldClock.day
		last_processed_day = WorldClock.day
		_persist()

func _state_key() -> StringName:
	return StringName("animal:%s" % String(persistent_id))

func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

## The world state the node saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_state_key())]) if persistent_id != &"" else PackedStringArray()
