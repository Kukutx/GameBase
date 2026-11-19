class_name ProgressionEventBus
extends Node

## What happened in the progression module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the progression
## module emits these. An argument named `<kind>_id` (or ending in
## `_<kind>_id`) is the id of an entry of that kind of content (`GameEvent`).

## A tool upgrade was collected as `result_item_id`.
signal tool_upgraded(tool_upgrade_id: StringName, result_item_id: StringName)
