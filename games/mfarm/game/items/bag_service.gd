class_name MFarmBagService
extends Node

## The bags of MFarm (`Bags`): the player's, each box's and each shop's, and
## the player's money. A bag is a fixed row of slots, each holding one item id
## and an amount. The first `ACTION_BAR_SIZE` slots of the player's bag are
## the action bar. The item of one slot (`selected`) is in the player's hands.
##
## Everything here persists in `WorldState` under `STATE_KEY`, so it saves
## with the world and a new game starts the player's bag, the money and the
## shops from their data (`MFarmBagData`) again.

signal bag_changed(bag_key: StringName)
signal money_changed(money: int)
signal selected_changed(index: int)

const STATE_KEY := &"mfarm:bags"
const PLAYER := &"player"
const PLAYER_TEMPLATE := &"player_bag"
const ACTION_BAR_SIZE := 10
const START_MONEY := 100
## The bag a box or shop starts from when its data names none.
const EMPTY_BOX_TEMPLATE := &"empty_box"

var money := START_MONEY
## The slot of the player's bag whose item is in their hands, or -1.
var selected := -1

## bag key -> Array[Dictionary] of {"item": StringName, "amount": int}.
var _bags: Dictionary = {}
var _loading := false

func _ready() -> void:
	WorldState.changed.connect(_on_world_changed)
	_load()

## Whether a bag exists under `bag_key`.
func has_bag(bag_key: StringName) -> bool:
	return _bags.has(bag_key)

## Makes the bag under `bag_key` from `template_id` unless it exists: a box
## or shop keeps what it holds once it was opened.
func ensure_bag(bag_key: StringName, template_id: StringName) -> void:
	if _bags.has(bag_key):
		return
	var template := MFarmBagData.find(template_id)
	if template == null:
		template = MFarmBagData.find(EMPTY_BOX_TEMPLATE)
	if template == null:
		return
	_bags[bag_key] = template.make_slots()
	_commit(bag_key)

## The slots of a bag, a copy.
func get_slots(bag_key: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: Dictionary in _bags.get(bag_key, []):
		result.append(slot.duplicate())
	return result

func get_slot(bag_key: StringName, index: int) -> Dictionary:
	var slots: Array = _bags.get(bag_key, [])
	if index < 0 or index >= slots.size():
		return {"item": &"", "amount": 0}
	return (slots[index] as Dictionary).duplicate()

func count(bag_key: StringName, item_id: StringName) -> int:
	var total := 0
	for slot: Dictionary in _bags.get(bag_key, []):
		if slot.item == item_id:
			total += int(slot.amount)
	return total

## How many of `amount` would fit in the bag.
func get_room_for(bag_key: StringName, item_id: StringName, amount: int) -> int:
	var room := 0
	for slot: Dictionary in _bags.get(bag_key, []):
		if slot.item == item_id:
			room += MFarmItemData.MAX_STACK - int(slot.amount)
		elif slot.item == &"":
			room += MFarmItemData.MAX_STACK
	return mini(room, amount)

## Adds up to `amount` of `item_id`, onto its stacks first, then into empty
## slots; returns how many went in. A full bag takes what fits and no more.
func add_item(bag_key: StringName, item_id: StringName, amount: int) -> int:
	if amount <= 0 or not _bags.has(bag_key) or MFarmItemData.find(item_id) == null:
		return 0
	var slots: Array = _bags[bag_key]
	var left := amount
	for pass_index: int in 2:
		for slot: Dictionary in slots:
			if left == 0:
				break
			var matches: bool = slot.item == item_id if pass_index == 0 else slot.item == &""
			if not matches:
				continue
			var added := mini(left, MFarmItemData.MAX_STACK - int(slot.amount))
			if added <= 0:
				continue
			slot.item = item_id
			slot.amount = int(slot.amount) + added
			left -= added
	if left != amount:
		_commit(bag_key)
	return amount - left

## Removes `amount` of `item_id` from the bag, from its last stacks first;
## false, removing nothing, when the bag holds fewer.
func remove_item(bag_key: StringName, item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if count(bag_key, item_id) < amount:
		return false
	var slots: Array = _bags[bag_key]
	var left := amount
	for index: int in range(slots.size() - 1, -1, -1):
		var slot: Dictionary = slots[index]
		if slot.item != item_id or left == 0:
			continue
		var taken := mini(left, int(slot.amount))
		slot.amount = int(slot.amount) - taken
		left -= taken
		if int(slot.amount) == 0:
			slot.item = &""
	_commit(bag_key)
	return true

## Removes up to `amount` from one slot; returns how many it removed.
func take_from_slot(bag_key: StringName, index: int, amount: int) -> int:
	var slots: Array = _bags.get(bag_key, [])
	if index < 0 or index >= slots.size():
		return 0
	var slot: Dictionary = slots[index]
	var taken := mini(amount, int(slot.amount))
	if taken <= 0:
		return 0
	slot.amount = int(slot.amount) - taken
	if int(slot.amount) == 0:
		slot.item = &""
	_commit(bag_key)
	return taken

## Moves the stack in one slot onto another, of the same bag or another: onto
## the same item it merges as far as the stack holds, otherwise the two swap.
## Shops take part only through `buy` and `sell`.
func move_slot(from_key: StringName, from_index: int, to_key: StringName, to_index: int) -> bool:
	if not _bags.has(from_key) or not _bags.has(to_key) or is_shop(from_key) or is_shop(to_key):
		return false
	var from_slots: Array = _bags[from_key]
	var to_slots: Array = _bags[to_key]
	if from_index < 0 or from_index >= from_slots.size() or to_index < 0 or to_index >= to_slots.size():
		return false
	if from_key == to_key and from_index == to_index:
		return false
	var source: Dictionary = from_slots[from_index]
	var target: Dictionary = to_slots[to_index]
	if source.item == &"":
		return false
	if target.item == source.item:
		var moved := mini(int(source.amount), MFarmItemData.MAX_STACK - int(target.amount))
		target.amount = int(target.amount) + moved
		source.amount = int(source.amount) - moved
		if int(source.amount) == 0:
			source.item = &""
	else:
		from_slots[from_index] = target
		to_slots[to_index] = source
	_commit(from_key)
	if to_key != from_key:
		_commit(to_key)
	return true

static func is_shop(bag_key: StringName) -> bool:
	return String(bag_key).begins_with("shop:")

## Buys `amount` of the item in a shop's slot: false, changing nothing, when
## the shop has fewer, the player lacks the money or the bag the room.
func buy(shop_key: StringName, index: int, amount: int) -> bool:
	var slot := get_slot(shop_key, index)
	var item := MFarmItemData.find(slot.item)
	if item == null or amount <= 0 or int(slot.amount) < amount:
		return false
	var cost := item.price * amount
	if cost > money or get_room_for(PLAYER, item.id, amount) < amount:
		return false
	take_from_slot(shop_key, index, amount)
	add_item(PLAYER, item.id, amount)
	set_money(money - cost)
	return true

## Sells `amount` of the item in a slot of the player's bag to a shop, which
## pays its sell price: false when it cannot be sold.
func sell(index: int, amount: int) -> bool:
	var slot := get_slot(PLAYER, index)
	var item := MFarmItemData.find(slot.item)
	if item == null or amount <= 0 or int(slot.amount) < amount or item.get_sell_price() <= 0:
		return false
	take_from_slot(PLAYER, index, amount)
	set_money(money + item.get_sell_price() * amount)
	return true

func set_money(value: int) -> void:
	money = maxi(value, 0)
	money_changed.emit(money)
	_save()

## Puts the item of a slot of the player's bag in their hands, or, for the
## slot in their hands already, empties their hands.
func select(index: int) -> void:
	var size: int = (_bags.get(PLAYER, []) as Array).size()
	var next := index if index >= 0 and index < size and index != selected and get_slot(PLAYER, index).item != &"" else -1
	if next == selected:
		return
	selected = next
	selected_changed.emit(selected)

## The item in the player's hands: the selected action bar slot's, or none.
func get_selected_item() -> MFarmItemData:
	if selected < 0:
		return null
	return MFarmItemData.find(get_slot(PLAYER, selected).item)

## Whether the player's bag holds what building `blueprint` takes.
func has_resources(blueprint: MFarmBlueprintData) -> bool:
	for index: int in blueprint.resources.size():
		if count(PLAYER, blueprint.resources[index]) < blueprint.amounts[index]:
			return false
	return true

func _commit(bag_key: StringName) -> void:
	bag_changed.emit(bag_key)
	if bag_key == PLAYER and selected >= 0 and get_slot(PLAYER, selected).item == &"":
		selected_changed.emit(selected)
	_save()

func _save() -> void:
	if _loading:
		return
	var bags: Dictionary = {}
	for key: StringName in _bags:
		var slots: Array = []
		for slot: Dictionary in _bags[key]:
			slots.append([String(slot.item), int(slot.amount)])
		bags[String(key)] = slots
	WorldState.set_value(STATE_KEY, {"money": money, "bags": bags})

func _on_world_changed(key: StringName, _value: Variant) -> void:
	if key == &"":
		_load()

# Reads the bags back from the world, keeping current items only; a world
# without them (a new game) starts the player's bag and money afresh, written
# to the world with the first change.
func _load() -> void:
	_loading = true
	_bags.clear()
	var state: Variant = WorldState.get_value(STATE_KEY)
	if state is Dictionary:
		money = SaveValues.count((state as Dictionary).get("money", START_MONEY))
		var bags: Variant = (state as Dictionary).get("bags", {})
		if bags is Dictionary:
			for key: Variant in bags:
				_bags[StringName(String(key))] = _read_slots(bags[key])
	else:
		money = START_MONEY
	selected = -1
	_loading = false
	if not _bags.has(PLAYER):
		var template := MFarmBagData.find(PLAYER_TEMPLATE)
		_bags[PLAYER] = template.make_slots() if template != null else []
	money_changed.emit(money)
	selected_changed.emit(selected)
	for key: StringName in _bags:
		bag_changed.emit(key)

static func _read_slots(raw: Variant) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if not raw is Array:
		return slots
	for entry: Variant in raw:
		var item := &""
		var amount := 0
		if entry is Array and (entry as Array).size() == 2:
			item = StringName(String(entry[0]))
			amount = mini(SaveValues.count(entry[1]), MFarmItemData.MAX_STACK)
		if amount == 0 or MFarmItemData.find(item) == null:
			item = &""
			amount = 0
		slots.append({"item": item, "amount": amount})
	return slots
