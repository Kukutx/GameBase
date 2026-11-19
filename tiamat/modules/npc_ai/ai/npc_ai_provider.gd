class_name NpcAiProvider
extends RefCounted

## Where an NPC's chat lines come from besides the rules the game wrote
## (`NpcRuleProvider`): a language model behind an endpoint (`NpcHttpProvider`)
## or a test's stand-in. `NpcAi` asks it one request at a time and falls back
## to the rules when it answers nothing or takes too long.

## What `NpcAiRequest.source` reads for its answers.
func get_source() -> StringName:
	return &"provider"

## The NPC's line for `request`, as the provider gives it (`NpcAi` cleans it);
## empty when it has none. It may await.
func reply(_request: NpcAiRequest) -> String:
	return ""
