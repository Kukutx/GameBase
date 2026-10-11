class_name ItemData
extends ContentEntry

enum Kind {
	MATERIAL,
	FOOD,
	SEED,
	TOOL,
	CROP,
	GIFT,
	QUEST,
	PLACEABLE,
}

## Tool actions the foundation's modules respond to. A game may give its tools
## other actions and handle them in its own code.
const ACTION_TILL := &"till"
const ACTION_WATER := &"water"
const ACTION_MINE := &"mine"
const ACTION_FISH := &"fish"

@export var display_name: String
@export_multiline var description: String
@export_range(1, 999, 1) var max_stack := 99
@export var icon: Texture2D
@export var kind: Kind = Kind.MATERIAL
@export_range(0, 999999, 1) var buy_price := 0
@export_range(0, 999999, 1) var sell_price := 0
@export_range(0, 999, 1) var energy_restore := 0
@export_range(0, 999, 1) var health_restore := 0
@export var food_buff_id: StringName
@export var tags: PackedStringArray = PackedStringArray()
## What the tool does: one of the ACTION_ constants, or an action of the game's own.
@export var tool_action: StringName
@export_range(1, 999, 1) var tool_power := 1
@export var crop_id: StringName
@export var placeable_id: StringName

func is_tool() -> bool:
	return kind == Kind.TOOL and tool_action != &""

func is_seed() -> bool:
	return kind == Kind.SEED and crop_id != &""

func is_placeable() -> bool:
	return kind == Kind.PLACEABLE and placeable_id != &""

func is_edible() -> bool:
	return energy_restore > 0 or health_restore > 0 or food_buff_id != &""

func has_tag(tag: String) -> bool:
	return tags.has(tag)
