class_name MiniGame
extends Control

## Base of a minigame scene run by `MiniGameHost`.
##
## The host adds the scene above the world, calls `setup()` with the merged
## settings and context, and waits for `finished`. A minigame calls `finish()`
## once; it never grants rewards itself, so the same minigame can serve any
## caller (the caller or the definition's actions decide what a win is worth).

signal finished(result: MiniGameResult)

var _finished := false

## Receives `MiniGameDefinition.settings` overridden by the caller's context.
func setup(_settings: Dictionary) -> void:
	pass

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

func _unhandled_input(event: InputEvent) -> void:
	if has_input() and event.is_action_pressed("ui_cancel"):
		finish(MiniGameResult.cancelled_result())
		get_viewport().set_input_as_handled()
