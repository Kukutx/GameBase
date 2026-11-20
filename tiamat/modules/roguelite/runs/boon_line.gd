class_name BoonLine
extends HudLine

## A line of the HUD with the boons the run going on took
## (`RunService.describe_boons()`): "Ember Edge ×2 · Fleet Foot". It hides
## while the run took none, and between runs.

func _init() -> void:
	hides_when_empty = true

func _watch() -> void:
	watch(RunState.boon_taken)
	watch(RunState.run_started)
	watch(RunState.run_ended)

func _get_parts() -> PackedStringArray:
	return RunState.describe_boons()
