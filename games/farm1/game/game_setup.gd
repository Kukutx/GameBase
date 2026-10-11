class_name GameSetup
extends GameModule

## Farm1's own module: what only this game knows, installed with the modules
## it enables (`GameModules`). It registers the tool action and the buff stat
## its player handles, the animals a new farm starts with, the data the modules
## read from slots the game fills, and the skill experience the player earns
## for what happens in the modules.

const MINE_FLOOR_TABLE := preload("res://game/data/mining/mine_floor_table.tres")
# instance id, animal id, location id, housing id, slot index
const START_ANIMALS := [
	[&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 0],
	[&"starter_cow_01", &"cow", &"starter_town", &"starter_barn", 0],
]

func install() -> void:
	ItemData.register_tool_action(MeleeController.TOOL_ACTION)
	for stat: StringName in [&"move_speed", &"tool_energy", &"attack_energy", &"attack_damage"]:
		GameStats.register_stat(stat)
	# After the lifesim module empties the animals (order 300).
	GameSession.register_new_game_step(&"start_animals", 310, _grant_start_animals)
	FishingState.reel_minigame_id = &"fishing_reel"
	MineState.floor_table = MINE_FLOOR_TABLE
	LifesimEvents.crop_harvested.connect(_on_crop_harvested)
	ItemsEvents.item_foraged.connect(_on_item_foraged)
	NpcSocialEvents.gift_given.connect(_on_gift_given)
	NpcSocialEvents.npc_talked.connect(_on_npc_talked)
	LifesimEvents.fish_caught.connect(_on_fish_caught)
	LifesimEvents.resource_mined.connect(_on_resource_mined)
	CombatEvents.enemy_defeated.connect(_on_enemy_defeated)

func _grant_start_animals() -> void:
	for animal: Array in START_ANIMALS:
		AnimalState.grant_animal(animal[0], animal[1], animal[2], animal[3], animal[4])

func _on_crop_harvested(_crop_id: StringName, _item_id: StringName, quantity: int) -> void:
	Skills.add_xp(&"farming", 25 * maxi(quantity, 1))

func _on_item_foraged(_item_id: StringName, quantity: int) -> void:
	Skills.add_xp(&"foraging", 10 * maxi(quantity, 1))

func _on_gift_given(_npc_id: StringName, _item_id: StringName, friendship_delta: int) -> void:
	if friendship_delta > 0:
		Skills.add_xp(&"social", 15)

func _on_npc_talked(_npc_id: StringName) -> void:
	Skills.add_xp(&"social", 2)

func _on_fish_caught(_fish_id: StringName, _item_id: StringName) -> void:
	Skills.add_xp(&"fishing", 20)

func _on_resource_mined(_node_id: StringName, _item_id: StringName, quantity: int) -> void:
	Skills.add_xp(&"mining", 12 * maxi(quantity, 1))

func _on_enemy_defeated(_enemy_id: StringName, combat_xp: int) -> void:
	Skills.add_xp(&"combat", maxi(combat_xp, 1))
