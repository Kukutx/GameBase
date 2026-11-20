class_name GameSetup
extends GameModule

## Ember Depths' own module: what only this game knows, installed with the
## modules it enables (`GameModules`). Floors are laid out fresh each time
## they are entered, so the player saves at camp, between runs (`RunState`),
## and a save slot shows the deepest depth its world reached. Every item the
## player gets goes to the hotbar, where it is swung, drunk or sold. The combat
## experience and the achievements are data: the triggers in
## `game/data/triggers/`. What the depths' chests hold is a way to get it
## (`ItemSources`).

const DEPTH_CHESTS := preload("res://game/depths/chests.tres")

func install() -> void:
	RunState.save_block_reason = "Return to camp to save"
	SaveManager.register_save_blocker(DepthRun.get_save_block_reason)
	SaveManager.register_slot_detail(&"deepest_depth", 100, DepthRun.describe_save)
	InventoryState.item_added.connect(_on_item_added)
	ItemSources.register(&"depth_chests", find_item_sources)

## The depths' chests as a way to get what they hold.
static func find_item_sources(_registry: ContentRegistry, sources: ItemSources) -> void:
	(DEPTH_CHESTS as ChestSpread).add_ways(sources, TranslationServer.translate("Found in chests in the depths"))

func _on_item_added(item_id: StringName, _quantity: int) -> void:
	Hotbar.ensure_item(item_id)
