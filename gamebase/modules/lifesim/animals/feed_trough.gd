class_name AnimalFeedTrough
extends Node2D

## Feeds the animals of one housing, each with the item its data names.

@export var housing_id: StringName
@export var display_name := "Animal Trough"

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	InventoryState.changed.connect(_refresh)
	WorldClock.day_changed.connect(_on_day_changed)
	AnimalState.ownership_changed.connect(_on_ownership_changed)
	AnimalState.housing_fed.connect(_on_housing_fed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var needs := AnimalState.get_feed_needs(housing_id)
	if needs.is_empty():
		GameEvents.toastf("%s animals are fed for today", [display_name])
		return
	var fed := AnimalState.feed_housing(housing_id)
	if fed > 0:
		GameEvents.toastf("Fed %d %s animals", [fed, display_name])
	else:
		GameEvents.toastf("No %s available", [_feed_names(needs)])
	_refresh()

func _on_day_changed(_day: int) -> void:
	_refresh()

func _on_ownership_changed(_location_id: StringName) -> void:
	_refresh()

func _on_housing_fed(changed_housing_id: StringName, _count: int) -> void:
	if changed_housing_id == housing_id:
		_refresh()

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _refresh() -> void:
	if interactable == null or label == null:
		return
	var needs := AnimalState.get_feed_needs(housing_id)
	if needs.is_empty():
		label.text = tr("%s\nFed today") % tr(display_name)
		interactable.set_prompt("%s fed", [display_name])
		return
	var unfed := 0
	for count: int in needs.values():
		unfed += count
	label.text = tr("%s\n%d need %s") % [tr(display_name), unfed, _feed_names(needs)]
	interactable.set_prompt("Feed %s x%d", [display_name, unfed])

## The translated names of the needed feed items.
func _feed_names(needs: Dictionary[StringName, int]) -> String:
	var names := PackedStringArray()
	for item_id: StringName in needs:
		var item := ItemData.find(item_id)
		names.append(tr(item.display_name) if item != null else String(item_id))
	return ", ".join(names)

## A trough feeds a housing of its own scene.
func find_scene_problems(_registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	var root: Node = self
	while root.get_parent() != null:
		root = root.get_parent()
	if housing_id == &"" or not _scene_has_housing(root):
		return PackedStringArray(["feed trough '%s' references unknown housing '%s'" % [name, housing_id]])
	return PackedStringArray()

func _scene_has_housing(node: Node) -> bool:
	if node is AnimalHousing and (node as AnimalHousing).housing_id == housing_id:
		return true
	for child: Node in node.get_children():
		if _scene_has_housing(child):
			return true
	return false
