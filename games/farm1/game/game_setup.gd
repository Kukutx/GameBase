extends Node

## Farm1's own setup, after its modules installed themselves (`GameModules`):
## the animals a new farm starts with and the data the modules read from slots
## the game fills.

const MINE_FLOOR_TABLE := preload("res://game/data/mining/mine_floor_table.tres")
# instance id, animal id, location id, housing id, slot index
const START_ANIMALS := [
	[&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 0],
	[&"starter_cow_01", &"cow", &"starter_town", &"starter_barn", 0],
]

func _ready() -> void:
	# After the lifesim module empties the animals (order 300).
	GameSession.register_new_game_step(&"start_animals", 310, _grant_start_animals)
	FishingState.reel_minigame_id = &"fishing_reel"
	MineState.floor_table = MINE_FLOOR_TABLE
	for problem: String in MINE_FLOOR_TABLE.validate(ContentDB):
		push_error("Mine: " + problem)

func _grant_start_animals() -> void:
	for animal: Array in START_ANIMALS:
		AnimalState.grant_animal(animal[0], animal[1], animal[2], animal[3], animal[4])
