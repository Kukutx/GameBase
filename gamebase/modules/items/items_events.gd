class_name ItemsEventBus
extends Node

## What happened in the items module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the items
## module emits these. An argument named `<kind>_id` (or ending in
## `_<kind>_id`) is the id of an entry of that kind of content (`GameEvent`).

## Items picked up from the world (forage, drops).
signal item_foraged(item_id: StringName, quantity: int)
