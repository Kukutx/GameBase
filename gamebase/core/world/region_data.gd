class_name RegionData
extends ContentEntry

## A part of the world that holds some locations (`WorldLocationData.region_id`),
## such as a valley or the coast: the player enters it when they travel to one
## of its locations from outside it (`WorldTravel.region_changed`), and content
## asks where they are with `REGION`.

const KIND := &"region"

@export var display_name: String

## The region with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RegionData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RegionData
