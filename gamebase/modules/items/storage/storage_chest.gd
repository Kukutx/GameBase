class_name StorageChest
extends PlacedStructure

@export var container_id: StringName = &"home_chest_01"
@export var display_name := "Storage Chest"
@export_range(1, 200, 1) var max_slots := 24

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func configure_from_record(record: Dictionary) -> void:
	super.configure_from_record(record)
	if placement_id != &"":
		container_id = placement_id

func can_pack_up() -> bool:
	if StorageState.get_used_slots(container_id) > 0:
		GameEvents.toast("Empty this chest before packing it up")
		return false
	return true

func on_removed() -> void:
	StorageState.clear_container(container_id)

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	StorageState.container_changed.connect(_on_container_changed)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("storage_menu") as StorageMenu
	if menu == null:
		GameEvents.toast("Storage menu is unavailable")
		return
	menu.open(container_id, display_name, max_slots)

func _on_container_changed(changed_id: StringName) -> void:
	if changed_id == container_id:
		_refresh()

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _refresh() -> void:
	if label == null or interactable == null:
		return
	var used := StorageState.get_used_slots(container_id)
	label.text = tr("%s\n%d/%d slots") % [tr(display_name), used, max_slots]
	interactable.set_prompt("Open %s", [display_name])
