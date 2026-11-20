class_name RunSummary
extends Node

## Tells the player what their last run brought (`RunState.get_last_report()`:
## its outcome, the tallies it raised, its boons) once they are back where
## this node is, a camp or a hub: when it enters the tree after a run ended, or
## when a run ends while it is in the tree. It waits until nothing holds the
## player's controls (a travel, passing out, a menu), then shows the report in
## a list with one choice (`ChoiceMenu.tell()`). Each report shows once.

## The player read the report on.
signal report_read

func _ready() -> void:
	RunState.run_ended.connect(_on_run_ended)
	set_process(_has_unseen_report())

## The list the report shows in, or null before it first showed one.
func get_menu() -> ChoiceMenu:
	return ChoiceMenu.of(self)

## Shows the last run's report now, when the player has not seen it; true when
## it did.
func show_report() -> bool:
	set_process(false)
	if not _has_unseen_report():
		return false
	var report := RunState.get_last_report()
	report.seen = true
	var menu := ChoiceMenu.tell(self, report.title, report.lines)
	menu.picked.connect(func(_choice_id: StringName) -> void: report_read.emit(), CONNECT_ONE_SHOT)
	return true

func _process(_delta: float) -> void:
	if not InputLock.is_locked() and not WorldTravel.is_traveling() and not GameSession.is_passing_out():
		show_report()

func _on_run_ended(_run: int, _outcome: StringName) -> void:
	set_process(_has_unseen_report())

func _has_unseen_report() -> bool:
	var report := RunState.get_last_report()
	return report != null and not report.seen
