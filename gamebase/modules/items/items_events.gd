class_name ItemsEventBus
extends Node

## What happened in the items module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the items
## module emits these.

## Items picked up from the world (forage, drops).
signal item_foraged(item_id: StringName, quantity: int)
