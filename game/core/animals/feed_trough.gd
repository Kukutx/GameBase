class_name AnimalFeedTrough
extends Node2D

@export var housing_id: StringName
@export var display_name := "Animal Trough"
@export var feed_item_id: StringName = &"hay"

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
	var unfed := AnimalState.get_unfed_count(housing_id)
	if unfed <= 0:
		GameEvents.toastf("%s animals are fed for today", [display_name])
		return
	var available := InventoryState.get_quantity(feed_item_id)
	if available <= 0:
		var feed := ContentDB.get_item(feed_item_id)
		GameEvents.toastf("No %s available", [feed.display_name if feed != null else "feed"])
		return
	var fed := AnimalState.feed_housing(housing_id, feed_item_id)
	if fed > 0:
		GameEvents.toastf("Fed %d %s animals", [fed, display_name])
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
	var unfed := AnimalState.get_unfed_count(housing_id)
	var feed := ContentDB.get_item(feed_item_id)
	var feed_name := feed.display_name if feed != null else "Feed"
	if unfed <= 0:
		label.text = tr("%s\nFed today") % tr(display_name)
		interactable.set_prompt("%s fed", [display_name])
	else:
		label.text = tr("%s\n%d need %s") % [tr(display_name), unfed, tr(feed_name)]
		interactable.set_prompt("Feed %s x%d", [display_name, unfed])
