extends Node2D

## A doorway of the old project: walking into its trigger takes the player to
## `target_location_id`, arriving at the spawn point `from_<this location>`
## there, or at the location's default spawn.

@export var target_location_id: StringName
## Where the old project put the player, kept for reference.
@export var target_position := Vector2.ZERO

func _ready() -> void:
	for child: Node in get_children():
		if child is Area2D:
			var area := child as Area2D
			area.collision_mask = 2
			area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player") or not WorldTravel.can_enter_portal():
		return
	var spawn := StringName("from_%s" % MFarmLocation.id_of(self))
	if not ContentRegistry.active.has_location_spawn(target_location_id, spawn):
		spawn = &""
	WorldTravel.travel_to(target_location_id, spawn)
