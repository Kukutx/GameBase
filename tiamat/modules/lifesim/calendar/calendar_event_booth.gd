class_name CalendarEventBooth
extends Node2D

@export var event_id: StringName
@export var idle_text := "Festival Booth"

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	EventState.active_events_changed.connect(_refresh)
	EventState.participation_claimed.connect(_on_participation_claimed)
	interactable.interacted.connect(_on_interacted)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var event := EventState.get_event(event_id)
	if event == null or not EventState.is_active(event_id):
		GameEvents.toast("This festival booth is closed")
		return
	if not event.has_participation_reward():
		GameEvents.toastf("%s", [event.display_name])
		return
	if EventState.has_claimed_participation(event_id):
		GameEvents.toastf("You already joined %s this year", [event.display_name])
		return
	if not EventState.claim_participation(event_id):
		GameEvents.toast("Could not claim the festival reward")
	_refresh()

func _on_participation_claimed(claimed_event_id: StringName, _year: int) -> void:
	if claimed_event_id == event_id:
		_refresh()

func _refresh() -> void:
	var event := EventState.get_event(event_id)
	var active := event != null and EventState.is_active(event_id)
	visible = active
	if interactable != null:
		interactable.enabled = active
	if not active:
		return
	var display := event.display_name if event != null else idle_text
	if label != null:
		label.text = "%s\n%s" % [tr(display), tr("Joined") if EventState.has_claimed_participation(event_id) else tr("Join for festival reward")]
	if interactable != null:
		interactable.set_prompt("Visit %s", [display])

func find_scene_problems(registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	var event := registry.get_entry(CalendarEventData.KIND, event_id) as CalendarEventData
	if event == null:
		return PackedStringArray(["event booth '%s' references unknown event '%s'" % [name, event_id]])
	if location != null and event.location_id != &"" and event.location_id != location.id:
		return PackedStringArray(["event booth '%s' references event '%s' from location '%s'" % [name, event_id, event.location_id]])
	return PackedStringArray()
