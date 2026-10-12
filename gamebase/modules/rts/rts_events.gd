class_name RtsEventBus
extends Node

## What happened in the rts module, for higher modules and the game to react
## to (quests, collections, sounds). Only the rts module emits these. An
## argument named `<kind>_id` (or ending in `_<kind>_id`) is the id of an entry
## of that kind of content (`GameEvent`).

## A command battle on `rts_map_id` ended: won, or lost or given up.
signal battle_ended(rts_map_id: StringName, won: bool)
## A foe of the player's side of kind `rts_unit_id` fell.
signal foe_defeated(rts_unit_id: StringName)
