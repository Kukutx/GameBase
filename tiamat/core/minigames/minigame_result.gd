class_name MiniGameResult
extends RefCounted

## How a minigame ended.

## Whether the player won. A cancelled minigame is never a success.
var success := false
## The player closed the minigame before it ended.
var cancelled := false
## Minigame-specific score; 0 when the minigame has none.
var score := 0
## Minigame-specific details for the caller.
var data: Dictionary = {}

static func won(score_value := 0, details: Dictionary = {}) -> MiniGameResult:
	var result := MiniGameResult.new()
	result.success = true
	result.score = score_value
	result.data = details
	return result

static func lost(score_value := 0, details: Dictionary = {}) -> MiniGameResult:
	var result := MiniGameResult.new()
	result.score = score_value
	result.data = details
	return result

static func cancelled_result() -> MiniGameResult:
	var result := MiniGameResult.new()
	result.cancelled = true
	return result
