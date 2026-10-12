class_name MiniGameHostService
extends Node

## Runs one minigame at a time above the world:
##
##     var result := await MiniGameHost.run(&"fishing_reel", {"difficulty": 0.4})
##
## While it runs the world can be paused, saving is blocked, and when it ends
## the definition's success or failure actions run through `GameRules`. It runs
## while its lock (`LOCK_REASON`) is on top and stands still while another
## lock is over it (the pause menu): nothing in it moves or reads input then.

signal minigame_started(minigame_id: StringName)
signal minigame_finished(minigame_id: StringName, result: MiniGameResult)

## Below the pause and settings menus, which can open over a minigame.
const LAYER := 90
## The reason of the `InputLock` lock a minigame holds while it runs.
const LOCK_REASON := &"minigame"

var _layer: CanvasLayer
var _active: MiniGame
var _active_id: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "MiniGameLayer"
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	SaveManager.register_save_blocker(_save_block_reason)
	GameSession.register_activity_end(cancel)
	InputLock.changed.connect(_update_running)

func is_running() -> bool:
	return _active != null

func get_active_id() -> StringName:
	return _active_id

## Starts the minigame `minigame_id` and waits for it to end. Returns a lost
## result at once when the minigame is unknown or another one is running.
func run(minigame_id: StringName, context: Dictionary = {}) -> MiniGameResult:
	var definition := MiniGameDefinition.find(minigame_id)
	if definition == null or definition.scene == null:
		push_error("MiniGameHost: unknown minigame '%s'" % minigame_id)
		return MiniGameResult.lost()
	if is_running():
		return MiniGameResult.lost(0, {"reason": "busy"})
	var minigame := definition.scene.instantiate() as MiniGame
	if minigame == null:
		push_error("MiniGameHost: scene of minigame '%s' does not extend MiniGame" % minigame_id)
		return MiniGameResult.lost()
	var settings := definition.settings.duplicate(true)
	settings.merge(context, true)
	_active = minigame
	_active_id = definition.id
	minigame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(minigame)
	# Its lock is on top while it runs, so it runs until a menu opens over it.
	InputLock.lock(LOCK_REASON, definition.pause_world, minigame)
	minigame.setup(settings)
	minigame_started.emit(definition.id)
	var result: MiniGameResult = await minigame.finished
	_active = null
	_active_id = &""
	minigame.queue_free()
	InputLock.unlock(LOCK_REASON)
	if result == null:
		result = MiniGameResult.lost()
	if not result.cancelled:
		GameRules.run_actions(definition.success_actions if result.success else definition.failure_actions, {"minigame_id": definition.id, "score": result.score})
	minigame_finished.emit(definition.id, result)
	return result

## Ends the running minigame as cancelled.
func cancel() -> void:
	if _active != null:
		_active.finish(MiniGameResult.cancelled_result())

# Runs the minigame while its lock is on top, the world paused or not, and
# stops it while another lock is over it.
func _update_running() -> void:
	if _active != null:
		_active.process_mode = Node.PROCESS_MODE_ALWAYS if InputLock.is_top(_active) else Node.PROCESS_MODE_DISABLED

func _save_block_reason() -> String:
	return tr("Finish the minigame before saving") if is_running() else ""
