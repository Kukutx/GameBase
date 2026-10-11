class_name LifesimEventBus
extends Node

## What happened in the lifesim module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the lifesim
## module emits these.

## A grown crop was harvested into `quantity` of `item_id`.
signal crop_harvested(crop_id: StringName, item_id: StringName, quantity: int)

## A farm animal's product was collected.
signal animal_product_collected(animal_id: StringName, item_id: StringName, quantity: int)

## A biting fish was landed.
signal fish_caught(fish_id: StringName, item_id: StringName)

## A mining node broke and dropped `quantity` of `item_id`.
signal resource_mined(node_id: StringName, item_id: StringName, quantity: int)

## A processing station's output was collected.
signal item_processed(recipe_id: StringName, item_id: StringName, quantity: int)
