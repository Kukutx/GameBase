class_name MFarmStorageBox
extends Node2D

## A box the player keeps items in. It starts with the stock of its bag data
## (`bag_id`, an empty box when none) the first time it is opened, then keeps
## what the player leaves in it. The player opens it standing next to it.

@export var bag_id: StringName
@export var box_index := 0
## The bag it keeps, set when built; otherwise named after its place.
var box_key := &""

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

func open() -> void:
	Bags.ensure_bag(box_key, bag_id)
	var menu := get_tree().get_first_node_in_group(&"mfarm_bag_menu")
	if menu != null:
		menu.call(&"open_box", box_key)

func _on_interacted(_actor: Node) -> void:
	open()
