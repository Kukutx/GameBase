class_name LifesimEventBus
extends Node

## What happened in the lifesim module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the lifesim
## module emits these. An argument named `<kind>_id` (or ending in
## `_<kind>_id`) is the id of an entry of that kind of content (`GameEvent`).

## A grown crop was harvested into `quantity` of `item_id`.
signal crop_harvested(crop_id: StringName, item_id: StringName, quantity: int)

## A farm animal's product was collected.
signal animal_product_collected(farm_animal_id: StringName, item_id: StringName, quantity: int)

## A biting fish was landed.
signal fish_caught(fish_id: StringName, item_id: StringName)

## A mining node broke and dropped `quantity` of `item_id`.
signal resource_mined(mining_node_id: StringName, item_id: StringName, quantity: int)

## A processing station's output was collected.
signal item_processed(processing_recipe_id: StringName, item_id: StringName, quantity: int)

## The player stayed up past the late night minute, passed out and woke up
## again (`LateNight`): at home, or where they fell when home could not open.
signal stayed_up_late(woke_at_home: bool)
