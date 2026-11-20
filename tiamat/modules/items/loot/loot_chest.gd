class_name LootChest
extends Node2D

## A chest in the world that holds a find (`LootTable`): the player opens it
## and takes what it holds, its items into the bag and its money into the
## wallet; what the bag cannot hold stays in the chest for later. It is filled
## once: by the place that lays it out (`fill()`, from the place's own stream:
## a floor of a run), or else from the world's stream of its key the first time
## it is opened. With a `persistent_id`, what it still holds saves in
## `WorldState`, so an emptied chest stays empty. A `locked` chest opens once
## it is unlocked (a floor cleared). It draws itself, closed or open, unless
## `drawn` is off for a game's own look as its children; the first time it
## opens, `ItemsEvents.chest_opened` tells of it.

## The player took `taken` from the chest.
signal opened(taken: LootTable.Find)

## What it holds.
@export var loot: LootTable
## The level of what it holds (a depth, a mine floor: `LootEntry.from_level`).
@export_range(0, 9999, 1, "or_greater") var level := 0
## Makes what it still holds persist in `WorldState`.
@export var persistent_id: StringName
## Whether it stays shut for now.
@export var locked := false:
	set(value):
		locked = value
		_refresh()
## What its prompt calls it.
@export var display_name := "Chest"
## Whether it draws itself.
@export var drawn := true
@export var body_color := Color(0.5, 0.32, 0.18)
@export var trim_color := Color(0.86, 0.68, 0.3)

@onready var interactable: Interactable = $Interactable

var _contents: LootTable.Find
var _opened := false

func _ready() -> void:
	if persistent_id != &"" and WorldState.has_value(_saved_key()):
		_contents = LootTable.Find.from_save_data(WorldState.get_value(_saved_key()))
		_opened = true
	interactable.interacted.connect(_on_interacted)
	_refresh()

## Fills the chest with a find at its level from `rolls`, the place's own
## stream; nothing once it was opened.
func fill(rolls: GameRandomStream) -> void:
	if _opened:
		return
	_contents = loot.roll(rolls, level) if loot != null else LootTable.Find.new()
	_refresh()

## What the chest holds now: rolled from the world's stream of its key when
## nothing filled it.
func get_contents() -> LootTable.Find:
	if _contents == null:
		fill(GameRandom.stream("chest:%s" % (String(persistent_id) if persistent_id != &"" else String(get_path()))))
	return _contents

## Whether it was opened.
func is_opened() -> bool:
	return _opened

## Whether it was opened and holds nothing more.
func is_emptied() -> bool:
	return _opened and get_contents().is_empty()

## Gives the player what the chest holds and their bag can hold, and gives what
## it gave: nothing while it is locked.
func open() -> LootTable.Find:
	var taken := LootTable.Find.new()
	if locked or is_emptied():
		return taken
	var contents := get_contents()
	var kept := false
	for item_id: StringName in contents.items.keys():
		var item := ItemData.find(item_id)
		var count := contents.items[item_id]
		var left := InventoryState.add_item(item, count) if item != null else 0
		if count > left and item != null:
			taken.items[item_id] = count - left
		if left > 0:
			contents.items[item_id] = left
			kept = true
		else:
			contents.items.erase(item_id)
	taken.money = contents.money
	Wallet.add(contents.money)
	contents.money = 0
	var first := not _opened
	_opened = true
	if persistent_id != &"":
		WorldState.set_value(_saved_key(), contents.to_save_data())
	if not taken.is_empty():
		GameEvents.toastf("Found %s", [taken.describe()])
	elif contents.is_empty():
		GameEvents.toastf("The %s is empty", [display_name])
	if kept:
		GameEvents.toast("Inventory is full")
	if first:
		ItemsEvents.chest_opened.emit(global_position)
	opened.emit(taken)
	_refresh()
	return taken

## The world state the chest saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_saved_key())]) if persistent_id != &"" else PackedStringArray()

## A chest in a scene needs something to hold.
func find_scene_problems(registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	if loot == null:
		return PackedStringArray(["loot chest '%s' has no loot table" % name])
	var problems := PackedStringArray()
	for problem: String in loot.find_problems(registry):
		problems.append("loot chest '%s': %s" % [name, problem])
	return problems

func _draw() -> void:
	if not drawn:
		return
	draw_rect(Rect2(-11, -7, 22, 13), body_color)
	draw_rect(Rect2(-11, -1, 22, 2), trim_color)
	if _opened:
		# The lid stands up behind the open box.
		draw_rect(Rect2(-11, -15, 22, 8), body_color.lightened(0.1))
		draw_rect(Rect2(-11, -15, 22, 2), trim_color)
		draw_rect(Rect2(-9, -7, 18, 3), body_color.darkened(0.6))
		if not get_contents().is_empty():
			draw_circle(Vector2(0, -6), 2.5, trim_color.lightened(0.3))
	else:
		draw_rect(Rect2(-12, -11, 24, 5), body_color.lightened(0.1))
		draw_rect(Rect2(-2, -4, 4, 5), trim_color.darkened(0.45) if locked else trim_color)

func _on_interacted(_actor: Node) -> void:
	open()

func _refresh() -> void:
	queue_redraw()
	if interactable == null:
		return
	interactable.enabled = not locked and not is_emptied()
	interactable.set_prompt("Open %s", [display_name])

func _saved_key() -> StringName:
	return StringName("chest:%s" % String(persistent_id))
