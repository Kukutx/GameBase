class_name GameNpc
extends CharacterBody2D

@export var profile: NpcProfileData
@export var location_id: StringName
@export var display_name: String = "Villager"
@export var dialogue: DialogueResource
@export var dialogue_title: String = "start"

@onready var label: Label = $NameLabel
@onready var activity_label: Label = $ActivityLabel
@onready var interactable: Interactable = $Interactable
@onready var schedule: NpcSchedule = $Schedule

func _ready() -> void:
	if profile != null:
		if not profile.display_name.is_empty():
			display_name = profile.display_name
		if not profile.schedule_entries.is_empty():
			schedule.entries = profile.schedule_entries
	if location_id == &"":
		var location := ContentDB.get_current_location(get_tree())
		if location != null:
			location_id = location.id
	label.text = display_name
	schedule.set_current_location(location_id)
	interactable.interacted.connect(_on_interacted)
	schedule.activity_changed.connect(_on_activity_changed)
	schedule.presence_changed.connect(_on_presence_changed)
	RelationshipState.friendship_changed.connect(_on_friendship_changed)
	_on_presence_changed(schedule.current_present)
	_on_activity_changed(schedule.current_activity)

func get_npc_id() -> StringName:
	if profile != null and profile.id != &"":
		return profile.id
	return StringName(display_name.to_snake_case())

func receive_gift(item_id: StringName) -> int:
	if profile == null:
		return 0
	return RelationshipState.give_gift(profile, item_id)

func get_relationship_text() -> String:
	return tr("%d hearts") % RelationshipState.get_hearts(get_npc_id())

func _on_interacted(actor: Node) -> void:
	var npc_id := get_npc_id()
	RelationshipState.record_talk(npc_id)
	NpcSocialEvents.npc_talked.emit(npc_id)
	ConversationService.start_conversation(self, actor, dialogue, dialogue_title)

func _on_activity_changed(activity: String) -> void:
	activity_label.text = "%s · %s" % [tr(activity), get_relationship_text()]

func _on_friendship_changed(npc_id: StringName, _points: int, _delta: int) -> void:
	if npc_id == get_npc_id():
		_on_activity_changed(schedule.current_activity)

func _on_presence_changed(present: bool) -> void:
	visible = present
	collision_layer = 4 if present else 0
	interactable.enabled = present
	interactable.monitorable = present
	interactable.collision_layer = 16 if present else 0
