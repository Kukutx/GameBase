class_name MFarmCropData
extends ContentEntry

## How a seed grows and what harvesting it gives. Its id is the seed item's.
## Trees, tree stumps, rocks and grass are crops too: what the player chops,
## breaks or reaps.

## The particles a harvest action shows.
enum Effect {
	NONE,
	LEAVES_GREEN,
	LEAVES_ORANGE,
	ROCK,
	GRASS,
}

const KIND := &"mfarm_crop"

## Days each stage lasts, the last being the ripe stage.
@export var growth_days: PackedInt32Array = PackedInt32Array([0])
## The sprite of each stage.
@export var stage_sprites: Array[Texture2D] = []
## The scene of each stage (the crop prefab).
@export var stage_scenes: Array[PackedScene] = []
## The seasons it can be planted in (0 spring to 3 winter).
@export var seasons: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
## The tools that harvest it, `required_actions[i]` uses of `harvest_tools[i]`.
@export var harvest_tools: Array[StringName] = []
@export var required_actions: PackedInt32Array = PackedInt32Array()
## What the crop turns into once harvested (a tree into its stump), or none.
@export var transfer_item_id: StringName
## What a harvest gives: between `produce_min[i]` and `produce_max[i]` of `produced_items[i]`.
@export var produced_items: Array[StringName] = []
@export var produce_min: PackedInt32Array = PackedInt32Array()
@export var produce_max: PackedInt32Array = PackedInt32Array()
## How far from the crop, in cells, what it gives falls to the ground.
@export var spawn_radius := Vector2.ZERO
@export var days_to_regrow := 0
@export var regrow_times := 0
## Whether what it gives goes straight to the player's bag.
@export var generate_at_player := false
## Whether its scene plays an animation on each action (a tree shakes and falls).
@export var has_animation := false
@export var effect: Effect = Effect.NONE
## Where the effect shows, from the crop's cell, in pixels.
@export var effect_offset := Vector2.ZERO
## The sound of each harvest action.
@export var sound_cue_id: StringName

static func find(entry_id: StringName) -> MFarmCropData:
	if entry_id == &"" or ContentRegistry.active == null:
		return null
	return ContentRegistry.active.get_entry(KIND, entry_id) as MFarmCropData

## Days from planting to ripe.
func get_total_days() -> int:
	var total := 0
	for days: int in growth_days:
		total += days
	return total

## The stage a crop is at after growing `days` days.
func get_stage(days: int) -> int:
	var remaining := days
	for stage: int in growth_days.size():
		remaining -= growth_days[stage]
		if remaining < 0:
			return stage
	return growth_days.size() - 1

func is_ripe(days: int) -> bool:
	return days >= get_total_days()

func can_grow_in(season: int) -> bool:
	return seasons.has(season)

## How many uses of `tool_id` harvest it, 0 when that tool does not.
func get_required_actions(tool_id: StringName) -> int:
	var index := harvest_tools.find(tool_id)
	return required_actions[index] if index >= 0 and index < required_actions.size() else 0

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if growth_days.is_empty():
		problems.append("has no stages")
	if stage_sprites.size() != growth_days.size() or stage_scenes.size() != growth_days.size():
		problems.append("needs a sprite and a scene for each of its %d stages" % growth_days.size())
	if harvest_tools.size() != required_actions.size():
		problems.append("lists %d tools but %d action counts" % [harvest_tools.size(), required_actions.size()])
	if produced_items.size() != produce_min.size() or produced_items.size() != produce_max.size():
		problems.append("lists %d products but not as many amounts" % produced_items.size())
	var items: Array[StringName] = [id, transfer_item_id]
	items.append_array(harvest_tools)
	items.append_array(produced_items)
	for item: StringName in items:
		if item != &"" and not registry.has_entry(MFarmItemData.KIND, item):
			problems.append("names unknown item '%s'" % item)
	if transfer_item_id != &"" and not registry.has_entry(KIND, transfer_item_id):
		problems.append("turns into '%s', which is no crop" % transfer_item_id)
	if sound_cue_id != &"":
		problems.append_array(AudioCueData.find_reference_problems(registry, "sound", sound_cue_id, AudioCueData.CueType.SFX))
	return problems
