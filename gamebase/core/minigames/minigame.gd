class_name MiniGame
extends Control

## Base of a minigame scene run by `MiniGameHost`.
##
## The host adds the scene above the world, calls `setup()` with the merged
## settings and context, and waits for `finished`. A minigame calls `finish()`
## once; it never grants rewards itself, so the same minigame can serve any
## caller (the caller or the definition's actions decide what a win is worth).

signal finished(result: MiniGameResult)

## How long after a cancel that asks to give the minigame up a second one
## does (`confirm_give_up()`), in seconds of real time.
const GIVE_UP_SECONDS := 2.0

var _finished := false
var _give_up_asked_at := -1

## Receives `MiniGameDefinition.settings` overridden by the caller's context.
func setup(_settings: Dictionary) -> void:
	pass

## What is wrong with `settings` a definition gives this minigame, checked with
## the rest of the content (`MiniGameDefinition.find_problems()`) on a scene
## that is not in the tree: an id of content that `registry` lacks, a value out
## of range. A setting left out is no problem, as the caller's context may
## give it.
func find_settings_problems(_settings: Dictionary, _registry: ContentRegistry) -> PackedStringArray:
	return PackedStringArray()

func finish(result: MiniGameResult) -> void:
	if _finished:
		return
	_finished = true
	finished.emit(result)

func is_finished() -> bool:
	return _finished

## Whether the minigame reads input now: it runs and nothing opened over it
## (`InputLock.is_top()`).
func has_input() -> bool:
	return not _finished and InputLock.is_top(self)

## Whether a cancel now gives the minigame up, for a minigame that asks first
## (a battle): it does within `GIVE_UP_SECONDS` of the cancel before. Else it
## only asks; the minigame then shows `get_give_up_prompt()`.
func confirm_give_up() -> bool:
	var now := Time.get_ticks_msec()
	var confirmed := _give_up_asked_at >= 0 and now - _give_up_asked_at <= int(GIVE_UP_SECONDS * 1000.0)
	_give_up_asked_at = -1 if confirmed else now
	return confirmed

## The words that ask for a second cancel to give the minigame up.
func get_give_up_prompt() -> String:
	return tr("Cancel again to give up.")

## The words of the minigame's outcome, won or lost.
func get_outcome_text(won: bool) -> String:
	return tr("Victory!") if won else tr("Defeat.")

func _unhandled_input(event: InputEvent) -> void:
	if has_input() and event.is_action_pressed("ui_cancel"):
		finish(MiniGameResult.cancelled_result())
		get_viewport().set_input_as_handled()
