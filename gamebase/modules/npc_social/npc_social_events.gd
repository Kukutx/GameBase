class_name NpcSocialEventBus
extends Node

## What happened in the npc_social module, for higher modules and the game to
## react to (quests, collections, skill experience, sounds). Only the npc_social
## module emits these.

## The player started talking to an NPC.
signal npc_talked(npc_id: StringName)

## The player gave an NPC a gift that changed their friendship by `friendship_delta`.
signal gift_given(npc_id: StringName, item_id: StringName, friendship_delta: int)
