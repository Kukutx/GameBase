class_name ProgressionEventBus
extends Node

## What happened in the progression module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the progression
## module emits these.

## A tool upgrade was collected as `result_item_id`.
signal tool_upgraded(upgrade_id: StringName, result_item_id: StringName)
