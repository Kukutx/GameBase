class_name GameSetup
extends GameModule

## Farm1's own module: what only this game knows, installed with the modules
## it enables (`GameModules`). It registers the stat its player's movement
## reads and the one that is the chance the player's hits set foes Burning
## (`BURN_CHANCE_STAT`, which Fire-Roasted Tomatoes' Fiery Belly raises), the
## animals a new farm starts with and the data the modules read from slots the
## game fills. The skill experience the player earns for what happens in the
## modules is data: the triggers in `game/data/triggers/`.

const MINE_FLOOR_TABLE := preload("res://game/data/mining/mine_floor_table.tres")
## The stat that is the chance, in percent, that a hit of the player's sets a
## foe Burning (`AfflictionData.chance_stat` of `burning.tres`).
const BURN_CHANCE_STAT := &"burn_chance"
# instance id, animal id, location id, housing id, slot index
const START_ANIMALS := [
	[&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 0],
	[&"starter_cow_01", &"cow", &"starter_town", &"starter_barn", 0],
]

func install() -> void:
	GameStats.register_stat(BURN_CHANCE_STAT, "Burn chance")
	# After the lifesim module empties the animals (order 300).
	GameSession.register_new_game_step(&"start_animals", 310, _grant_start_animals)
	FishingState.reel_minigame_id = &"fishing_reel"
	MineState.floor_table = MINE_FLOOR_TABLE

func _grant_start_animals() -> void:
	for animal: Array in START_ANIMALS:
		AnimalState.grant_animal(animal[0], animal[1], animal[2], animal[3], animal[4])
