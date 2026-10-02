class_name BasicSprinkler
extends PlacedStructure

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_refresh()

func configure_from_record(record: Dictionary) -> void:
	super.configure_from_record(record)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var data := get_placeable_data()
	var radius := data.effect_radius if data != null else 0.0
	GameEvents.toast("Basic Sprinkler · waters nearby plots every morning (%.0f px)" % radius)

func _refresh() -> void:
	if label != null:
		label.text = "Sprinkler"
	if interactable != null:
		interactable.prompt_text = "Check Sprinkler"
