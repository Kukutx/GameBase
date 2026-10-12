class_name TacticsEventBus
extends Node

## What happened in the tactics module, for higher modules and the game to
## react to (quests, collections, sounds). Only the tactics module emits these.
## An argument named `<kind>_id` (or ending in `_<kind>_id`) is the id of an
## entry of that kind of content (`GameEvent`).

## A grid battle on `battle_map_id` ended: won, or lost or given up.
signal battle_ended(battle_map_id: StringName, won: bool)
## A unit of the player's side defeated a foe of kind `battle_unit_id`.
signal foe_defeated(battle_unit_id: StringName)
