class_name GameDefinition
extends Resource

## The facts the foundation needs about the game that is running on it.
##
## `gamebase/core` never names a location, item or other content id of a
## particular game. A game provides one `GameDefinition` resource and points the
## `gamebase/game_definition` project setting at it; `GameSession` loads it.

## Location a new game starts in, and the fallback when a save's location is gone.
@export var start_location_id: StringName = &""
## Location the player is brought back to after collapsing or staying up too late.
@export var home_location_id: StringName = &""
## Spawn point used when the player is brought home.
@export var home_spawn_id: StringName = &""
## Clock at the start of a new game.
@export_range(1, 100000) var start_day := 1
@export_range(0, 1439) var start_minute_of_day := 8 * 60
## Seed of the deterministic weather and other world randomness of a new game.
@export var world_seed := 0
## Items granted at the start of a new game, as item id → amount.
@export var start_items: Dictionary[StringName, int] = {}
