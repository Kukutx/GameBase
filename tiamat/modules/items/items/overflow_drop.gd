class_name OverflowDrop
extends RefCounted

## What a node gives the player that their bag cannot hold: it waits on the
## ground by the node (a `WorldItemPickup` that is not forage) until they take
## it, and its count (`quantity`) saves with the node, so it lies there again
## when the place loads. A creature's loot (`HostileCreature`) and a mined
## rock's ore (`MiningNode`) overflow here; anything else that hands out items
## in the world can.

## The count on the ground changed as the player took some or more fell: the
## node saves it.
signal changed

const PICKUP_SCENE := preload("res://tiamat/modules/items/items/item_pickup.tscn")

## How many wait on the ground.
var quantity := 0
## Where they lie from the node.
var offset := Vector2.ZERO
var _pickup: WorldItemPickup

func _init(at := Vector2.ZERO) -> void:
	offset = at

## Gives the player `amount` of `item`; what their bag cannot hold joins what
## waits on the ground. Returns that share; `show` lays it down.
func give(item: ItemData, amount: int) -> int:
	if item == null or amount <= 0:
		return 0
	var remaining := InventoryState.add_item(item, amount)
	if remaining > 0:
		quantity += remaining
		changed.emit()
	return remaining

## Lays what waits of `item` on the ground by `node`, or counts it again on
## the pile already there. Nothing while none waits or no scene holds it. A hit
## can come from a physics callback, where no area may enter the world: from
## one, call it deferred.
func show(node: Node2D, item: ItemData) -> void:
	if quantity <= 0 or item == null or not node.is_inside_tree() or node.get_tree().current_scene == null:
		return
	if is_instance_valid(_pickup):
		_pickup.set_quantity(quantity)
		return
	_pickup = make_pickup(item, quantity)
	_pickup.items_collected.connect(_on_collected)
	node.get_tree().current_scene.add_child(_pickup)
	_pickup.global_position = node.global_position + offset

## Takes the count a node saved, any whole number from 0 up: what waits may be
## more than one drop.
func load_count(raw: Variant) -> void:
	quantity = SaveValues.count(raw)

## A pile of `amount` of `item` that the player picks up, not counted as
## forage.
static func make_pickup(item: ItemData, amount: int) -> WorldItemPickup:
	var pickup := PICKUP_SCENE.instantiate() as WorldItemPickup
	pickup.item = item
	pickup.quantity = maxi(amount, 1)
	pickup.counts_as_forage = false
	return pickup

func _on_collected(_item_id: StringName, _collected: int, remaining: int) -> void:
	quantity = maxi(remaining, 0)
	if quantity <= 0:
		_pickup = null
	changed.emit()
