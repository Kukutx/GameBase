class_name NpcAiRequest
extends RefCounted

## One line an NPC is asked for in a chat (`NpcAi.ask()`): the NPC, the topic
## the player brought up (none for the greeting), what the NPC knows
## (`NpcContext`) and the messages it remembers that bear on it. `NpcAi` answers
## it once, from a provider or the rules; `wait()` gives the answer. A request
## given up (`cancel()`) is never answered, and whoever gives it up waits no
## more.

## The answer came.
signal finished
## The request no longer waits: it was answered or given up.
signal settled

var npc_id: StringName
## The topic the player brought up; null when the player walks up to the NPC.
var topic: ChatTopicData
## What the player says, in the language the game shows.
var player_text := ""
## What the NPC knows (`NpcContext.build_context()`).
var context: Dictionary = {}
## The latest messages of the NPC's memory, oldest first.
var recent: Array[Dictionary] = []
## Older messages that bear on `player_text` (`NpcMemoryRecall`), oldest first.
var recalled: Array[Dictionary] = []
## The language the NPC answers in, as `TranslationServer.get_locale()` gives it.
var locale := ""

## The answer, once `is_done()`.
var text := ""
## Where the answer came from: `NpcAiService.SOURCE_RULES` or the provider's
## `get_source()`.
var source := &""
var _done := false
var _cancelled := false

func is_done() -> bool:
	return _done

## Gives up on the answer: `NpcAi` skips the request if it has not started on
## it, goes on to the next if it has, and drops an answer that comes later.
func cancel() -> void:
	if _done or _cancelled:
		return
	_cancelled = true
	settled.emit()

func is_cancelled() -> bool:
	return _cancelled

## The answer, once there is one; empty for a request already given up.
func wait() -> String:
	if not _done and not _cancelled:
		await finished
	return text

## Settles the request with `answer` from `answer_source`: false, and nothing
## changed, when it already has an answer or was given up.
func finish(answer: String, answer_source: StringName) -> bool:
	if _done or _cancelled:
		return false
	_done = true
	text = answer
	source = answer_source
	finished.emit()
	settled.emit()
	return true
