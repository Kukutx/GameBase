class_name AutoSaveService
extends Node

## Saves the game on its own: every `interval_seconds`, after each travel and
## when the window closes, while `GameSettings.autosave` is on and the game can
## be saved. A save that works shows on the game's `SaveIndicator`; one that
## fails tells the player why with a toast.

signal autosave_completed(success: bool, reason: String)
## Emitted before `autosave_completed` when the save could not be written:
## `problem` is the reason, in the player's language.
signal autosave_failed(reason: String, problem: String)
signal autosave_skipped(reason: String, block_reason: String)

const DEFAULT_INTERVAL_SECONDS := 300.0
const MIN_SAVE_GAP_MSEC := 2000

@export_range(30.0, 1800.0, 30.0) var interval_seconds := DEFAULT_INTERVAL_SECONDS

var _timer: Timer
var _busy := false
var _last_save_msec := -MIN_SAVE_GAP_MSEC

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.name = "AutosaveTimer"
	_timer.wait_time = interval_seconds
	_timer.one_shot = false
	_timer.autostart = true
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)
	WorldTravel.travel_finished.connect(_on_travel_finished)
	SaveManager.save_completed.connect(_on_manual_save_completed)
	GameSettings.changed.connect(_sync_enabled_state)
	_sync_enabled_state()

func request_autosave(reason: String = "interval") -> bool:
	if not GameSettings.autosave or _busy:
		return false
	if Time.get_ticks_msec() - _last_save_msec < MIN_SAVE_GAP_MSEC:
		autosave_skipped.emit(reason, "recent_save")
		return false
	var block_reason := SaveManager.get_save_block_reason()
	if not block_reason.is_empty():
		autosave_skipped.emit(reason, block_reason)
		return false
	_busy = true
	var problem := SaveManager.write_save()
	_busy = false
	var success := problem.is_empty()
	if success:
		_last_save_msec = Time.get_ticks_msec()
	else:
		# The save manager logged what could not be written. The reason is
		# already in the player's language, so it is not translated again.
		autosave_failed.emit(reason, problem)
		GameEvents.toast_requested.emit(problem)
	autosave_completed.emit(success, reason)
	return success

func _notification(what: int) -> void:
	# The window is closing: the handlers run before the tree quits, so the last
	# minutes of play are written when autosave is on and the game can be saved.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_autosave("quit")

func _on_timer_timeout() -> void:
	request_autosave("interval")

func _on_travel_finished(_scene_path: String, _spawn_id: StringName) -> void:
	_autosave_after_travel.call_deferred()

func _autosave_after_travel() -> void:
	# Let the destination scene and any travel completion listeners settle first.
	# This also allows collapse/sleep flows to perform their explicit save before
	# the autosave de-duplication check runs.
	await get_tree().process_frame
	await get_tree().process_frame
	request_autosave("travel")

func _on_manual_save_completed(success: bool, _message: String) -> void:
	if success:
		_last_save_msec = Time.get_ticks_msec()

func _sync_enabled_state() -> void:
	if _timer == null:
		return
	_timer.wait_time = maxf(interval_seconds, 30.0)
	_timer.paused = not GameSettings.autosave
