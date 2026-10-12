class_name DialogueService
extends Node

## Shows one conversation at a time in a `DialogueBalloon` in the current
## scene: the lines of a dialogue file from one of its titles
## (`show_dialogue()`, read by the `DialogueManager` addon) or those of a chat
## made while it runs (`show_chat()`). Any system shows one this way: an NPC's
## talk (`ConversationService`), a sign or a camp's keeper (`DialogueSpot`).
##
## While a conversation shows, it holds the player's controls and pauses the
## world (`InputLock`, reason `LOCK`), so the clock stands still while the
## player reads. The addon runs while the world is paused, so its mutations and
## their waits do too; a node a mutation waits on (a tween, an animation) has to
## run while paused as well (`process_mode`). `finished` says a dialogue file was
## read to its end; a balloon that leaves first (a load, the title) gives the
## controls back without it. The service saves nothing.

## The dialogue file `resource` was read to its end.
signal finished(resource: DialogueResource)

## The `InputLock` reason a conversation holds the player's controls under.
const LOCK := &"dialogue"
const BALLOON_SCENE := preload("res://gamebase/modules/dialogue/dialogue_balloon.tscn")

var _balloon: Node
var _resource: DialogueResource

func _ready() -> void:
	DialogueManager.process_mode = Node.PROCESS_MODE_ALWAYS
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

## Whether a conversation shows now.
func is_showing() -> bool:
	return is_instance_valid(_balloon)

## Shows `resource` from `title` on, its lines reading `game_states` (the nodes
## they name); null, and nothing shows, when the dialogue has no such title or
## another conversation shows, which the player is told.
func show_dialogue(resource: DialogueResource, title := "start", game_states: Array = []) -> DialogueBalloon:
	if not has_title(resource, title) or _refuse_while_showing():
		return null
	var balloon := _add_balloon(resource)
	balloon.start(resource, title, game_states)
	return balloon

## Shows `chat`'s lines; null when another conversation shows, which the player
## is told.
func show_chat(chat: DialogueChat) -> DialogueBalloon:
	if chat == null or _refuse_while_showing():
		return null
	var balloon := _add_balloon(null)
	balloon.start_chat(chat)
	return balloon

## Whether `resource` has lines under `title` (empty: from its first line).
static func has_title(resource: DialogueResource, title: String) -> bool:
	if resource == null:
		return false
	if title.is_empty():
		return not resource.first_cue.is_empty() or not resource.lines.is_empty()
	return resource.cues.has(title) or resource.lines.has(title)

func _refuse_while_showing() -> bool:
	if not is_showing():
		return false
	GameEvents.toast("Finish the current conversation first")
	return true

# A balloon in the current scene that holds the controls while it shows
# `resource` (null: a chat).
func _add_balloon(resource: DialogueResource) -> DialogueBalloon:
	var balloon := BALLOON_SCENE.instantiate() as DialogueBalloon
	var scene := get_tree().current_scene
	(scene if scene != null else get_tree().root).add_child(balloon)
	_hold_controls(balloon, resource)
	return balloon

# The player stays put and the world waits while `balloon` shows `resource`:
# the lock is given back when the dialogue ends or the balloon leaves the tree,
# whichever comes first.
func _hold_controls(balloon: Node, resource: DialogueResource) -> void:
	_balloon = balloon
	_resource = resource
	# The lock's owner: its leaving gives the lock back.
	InputLock.lock(LOCK, true, balloon)
	balloon.tree_exited.connect(_on_balloon_exited.bind(balloon), CONNECT_ONE_SHOT)

func _on_dialogue_ended(resource: DialogueResource) -> void:
	if resource == null or resource != _resource:
		return
	_resource = null
	InputLock.unlock(LOCK)
	finished.emit(resource)

func _on_balloon_exited(balloon: Node) -> void:
	if balloon == _balloon:
		_balloon = null
		_resource = null
