class_name GamePlayer
extends CharacterBody2D

@export var move_speed: float = 115.0
@export var interaction_offset: float = 18.0

@onready var interaction_controller: InteractionController = $InteractionController
@onready var farm_tool_controller: FarmToolController = $FarmToolController
@onready var melee_controller: MeleeController = $MeleeController
@onready var actor_visual: DirectionalActorVisual = $ActorVisual

var _previous_health := 0

func _ready() -> void:
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager != null:
		dialogue_manager.dialogue_started.connect(_on_dialogue_started)
		dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	_previous_health = PlayerState.health
	PlayerState.health_changed.connect(_on_health_changed)

func _physics_process(_delta: float) -> void:
	if _is_input_locked():
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed * GameStats.get_multiplier(&"move_speed")
	move_and_slide()

	if direction.length_squared() > 0.01:
		var target_offset := direction.normalized() * interaction_offset
		interaction_controller.position = target_offset
		farm_tool_controller.position = target_offset
		melee_controller.position = target_offset

func _unhandled_input(event: InputEvent) -> void:
	if _is_input_locked():
		return
	if event.is_action_pressed("give_gift"):
		_give_selected_gift()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("remove_building"):
		_remove_focused_building()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hotbar_prev"):
		Hotbar.cycle_slot(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hotbar_next"):
		Hotbar.cycle_slot(1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := _slot_for_key(event.physical_keycode)
		if slot >= 0:
			Hotbar.select_slot(slot)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Hotbar.cycle_slot(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Hotbar.cycle_slot(1)
			get_viewport().set_input_as_handled()

func _give_selected_gift() -> void:
	var focused := interaction_controller.get_focused()
	if focused == null:
		GameEvents.toast("Stand near someone to give a gift")
		return
	var npc := focused.get_parent() as GameNpc
	if npc == null:
		GameEvents.toast("That is not someone you can gift")
		return
	var item_id := Hotbar.get_selected_item_id()
	if item_id == &"":
		GameEvents.toast("Select a gift in the hotbar")
		return
	npc.receive_gift(item_id)

func _remove_focused_building() -> void:
	var focused := interaction_controller.get_focused()
	if focused == null:
		GameEvents.toast("Stand near a placed structure to pack it up")
		return
	var structure := focused.get_parent() as PlacedStructure
	if structure == null or structure.placement_id == &"" or structure.location_id == &"":
		GameEvents.toast("That cannot be packed up")
		return
	var data := structure.get_placeable_data()
	if BuildingState.remove_placement(structure.location_id, structure.placement_id, true):
		GameEvents.toastf("Packed up %s", [data.display_name if data != null else "structure"])

func _slot_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
	return -1

# A menu, a dialogue, fishing or a minigame holds the controls (`InputLock`),
# or the player's own action is still playing.
func _is_input_locked() -> bool:
	return InputLock.is_locked() or (actor_visual != null and actor_visual.is_action_playing())

func _on_dialogue_started(_resource: DialogueResource) -> void:
	InputLock.lock(&"dialogue", false, self)

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	InputLock.unlock(&"dialogue")

func _on_health_changed(current: int, _maximum: int) -> void:
	if current < _previous_health and actor_visual != null:
		actor_visual.play_action(&"death" if current <= 0 else &"hurt")
	_previous_health = current
