class_name CombatEventBus
extends Node

## What happened in the combat module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the combat
## module emits these. An argument named `<kind>_id` (or ending in
## `_<kind>_id`) is the id of an entry of that kind of content (`GameEvent`).

## A hostile creature was defeated; `combat_xp` is its `EnemyData.combat_xp`.
signal enemy_defeated(enemy_id: StringName, combat_xp: int)
