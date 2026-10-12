class_name InputLockService
extends Node

## Who holds the player's controls and the world's pause, by reason. A menu, a
## dialogue, a minigame or a cutscene takes a lock under a reason of its own
## and gives it back when it is done. The player acts only while no reason
## holds a lock, and the world (the scene tree) is paused while any lock that
## pauses is held. Locks add up, so one that ends never frees what another
## holds: a menu that closes while a minigame runs leaves the world paused.
##
## A lock taken with an `owner` is given back when the owner leaves the tree,
## so a menu freed by a scene change never leaves the game locked. Nothing but
## this service sets `SceneTree.paused` (`tools/check_code.js`).

signal changed

# reason -> {"pause": bool, "owner": Node or null, "release": Callable}
var _locks: Dictionary[StringName, Dictionary] = {}

## Takes the lock `reason` names; taking it again replaces it.
func lock(reason: StringName, pause_world := false, owner: Node = null) -> void:
	if reason == &"":
		return
	_release_owner(reason)
	var entry := {"pause": pause_world, "owner": owner, "release": Callable()}
	if owner != null:
		# A callable of its own per lock: bound callables of one method compare
		# equal whatever they bind, so one owner's second lock would not connect.
		var release := func() -> void: unlock(reason)
		owner.tree_exiting.connect(release)
		entry["release"] = release
	_locks[reason] = entry
	_apply()

func unlock(reason: StringName) -> void:
	if not _locks.has(reason):
		return
	_release_owner(reason)
	_locks.erase(reason)
	_apply()

## Whether any reason holds a lock: the player may not act.
func is_locked() -> bool:
	return not _locks.is_empty()

## Whether `event` presses `action` for the player: the input map has the
## action, the event presses it and no reason holds a lock. A handler of a
## player action acts only then, leaving a press made while the controls are
## locked to whoever holds them (a fishing cast reels in with it).
func is_player_press(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action) and not is_locked()

func is_held(reason: StringName) -> bool:
	return _locks.has(reason)

## The reasons holding a lock, sorted.
func get_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	reasons.assign(_locks.keys())
	reasons.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return reasons

## Gives back every lock, as when the game returns to its title.
func clear() -> void:
	for reason: StringName in _locks.keys():
		_release_owner(reason)
	_locks.clear()
	_apply()

func _apply() -> void:
	var pause := false
	for entry: Dictionary in _locks.values():
		pause = pause or bool(entry["pause"])
	if get_tree().paused != pause:
		get_tree().paused = pause
	changed.emit()

func _release_owner(reason: StringName) -> void:
	var entry: Dictionary = _locks.get(reason, {})
	var owner: Variant = entry.get("owner")
	var release: Callable = entry.get("release", Callable())
	if is_instance_valid(owner) and release.is_valid() and (owner as Node).tree_exiting.is_connected(release):
		(owner as Node).tree_exiting.disconnect(release)
