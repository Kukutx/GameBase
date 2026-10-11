class_name CombatEventBus
extends Node

## What happened in the combat module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the combat
## module emits these.

## A hostile creature was defeated; `combat_xp` is its `EnemyData.combat_xp`.
signal enemy_defeated(enemy_id: StringName, combat_xp: int)
