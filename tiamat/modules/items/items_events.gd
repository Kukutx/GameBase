class_name ItemsEventBus
extends Node

## What happened in the items module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the items
## module emits these. An argument named `<kind>_id` (or ending in
## `_<kind>_id`) is the id of an entry of that kind of content (`GameEvent`);
## `position` is where in the world it happened (global), where a sound of it
## plays (`GameAudio`).

## Items picked up from the world (forage, drops).
signal item_foraged(item_id: StringName, quantity: int, position: Vector2)
## The world's lasting upgrade `stat_upgrade_id` reached `level`
## (`StatUpgradeData`), bought at a stand or given by content.
signal stat_upgraded(stat_upgrade_id: StringName, level: int)
