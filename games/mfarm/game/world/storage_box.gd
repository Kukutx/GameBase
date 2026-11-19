class_name MFarmStorageBox
extends Node2D

## A box the player keeps items in. It starts with the stock of its bag data
## (`bag_id`, an empty box when none) the first time it is opened, then keeps
## what the player leaves in it. Standing next to it the player sees the
## mouse sign over it and opens it with the right mouse button, as in the old
## game, or with the interact key; walking away closes it.

@export var bag_id: StringName
@export var box_index := 0
## The bag it keeps, set when built; otherwise named after its place.
var box_key := &""

var _near := false
var _sign: CanvasItem

func _ready() -> void:
	if box_key == &"":
		box_key = StringName("box:%s:%s" % [MFarmLocation.id_of(self), MFarmLocation.key_of(self)])
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.prompt_text = "Open the box"
	interactable.collision_layer = 16
	interactable.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	shape.position = Vector2(0, -10)
	interactable.add_child(shape)
	add_child(interactable)
	interactable.interacted.connect(_on_interacted)
	_sign = get_node_or_null(^"Sign") as CanvasItem
	var trigger := get_node_or_null(^"Trigger") as Area2D
	if trigger != null:
		trigger.collision_mask |= 2
		trigger.body_entered.connect(_on_trigger.bind(true))
		trigger.body_exited.connect(_on_trigger.bind(false))

func is_player_near() -> bool:
	return _near

func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _near and click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and not InputLock.is_locked():
		get_viewport().set_input_as_handled()
		open()

func _on_trigger(body: Node2D, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	_near = entered
	if _sign != null:
		_sign.visible = entered
	if not entered:
		var menu := get_tree().get_first_node_in_group(&"mfarm_bag_menu")
		if menu != null and menu.call(&"get_open_bag") == box_key:
			menu.call(&"close")

func open() -> void:
	Bags.ensure_bag(box_key, bag_id)
	var menu := get_tree().get_first_node_in_group(&"mfarm_bag_menu")
	if menu != null:
		menu.call(&"open_box", box_key)

func _on_interacted(_actor: Node) -> void:
	open()
