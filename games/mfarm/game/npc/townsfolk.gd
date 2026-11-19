class_name MFarmTownsfolk
extends Node2D

## Places the townsfolk whose schedule has them in this location now (or
## who start here) when the location opens. Put it on the y-sorted layer
## the player walks on, so that they pass in front of and behind each other.

func _ready() -> void:
	y_sort_enabled = true
	var location_id := MFarmLocation.id_of(self)
	var map := MFarmMapData.find(location_id)
	for npc: MFarmNpcData in MFarmNpcData.find_all():
		var entry := npc.get_entry_at(WorldClock.minute_of_day)
		var here := entry.location_id if entry != null else npc.start_location_id
		if here != location_id:
			continue
		var node := MFarmNpc.new()
		node.setup(npc, map)
		add_child(node)
