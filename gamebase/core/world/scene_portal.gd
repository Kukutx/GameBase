class_name ScenePortal
extends Area2D

@export var target_location_id: StringName
@export var target_spawn_id: StringName
@export var enabled := true

var _travel_requested := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not enabled or _travel_requested or not body.is_in_group("player"):
		return
	if not WorldTravel.can_enter_portal():
		return
	_travel_requested = true
	enabled = false
	_start_travel.call_deferred()

func _start_travel() -> void:
	if target_location_id == &"":
		_reopen()
		GameEvents.toast("Portal target is unavailable")
		return
	if not WorldTravel.travel_to(target_location_id, target_spawn_id):
		_reopen()
		return
	# Not awaited: an arrival frees this portal with its location.
	WorldTravel.travel_ended.connect(_on_travel_ended, CONNECT_ONE_SHOT)

# A travel that failed after it started leaves the player here.
func _on_travel_ended(arrived: bool) -> void:
	if not arrived:
		_reopen()

func _reopen() -> void:
	_travel_requested = false
	enabled = true
