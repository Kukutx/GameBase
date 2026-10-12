class_name CombatEventBus
extends Node

## What happened in the combat module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the combat
## module emits these. An argument named `<kind>_id` (or ending in
## `_<kind>_id`) is the id of an entry of that kind of content (`GameEvent`).

## A hostile creature was defeated; `combat_xp` is its `EnemyData.combat_xp`.
signal enemy_defeated(enemy_id: StringName, combat_xp: int)

## The player swung the weapon `weapon_item_id`, hitting or not.
signal attack_swung(weapon_item_id: StringName)
## A hostile creature was hurt for `amount`.
signal enemy_hurt(enemy_id: StringName, amount: int)
## The player was hurt for `amount`.
signal player_hurt(amount: int)
## The player lost all their health and woke up again; `money_lost` is what
## the defeat cost (`CombatSettings.defeat_money_loss_percent`).
signal player_defeated(money_lost: int)
