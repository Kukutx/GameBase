class_name MiniGameStation
extends Node2D

## Something in the world the player uses to play a minigame
## (`MiniGameDefinition`): a war table, an arcade cabinet, a card table. With
## the `Interactable` child the station needs, interact runs `minigame_id`
## through `MiniGameHost`, with `context` over the minigame's own settings, and
## `played` says how it went. A station that offers several minigames lists
## its `choices` for the player to pick from first (`MiniGamePicker`): a
## campaign's battles, each open once its condition holds
## (`MINIGAME_WON ford_battle`). A game draws the station itself, as children
## of its instance of `minigame_station.tscn`.

## The minigame ended, or could not start (`MiniGameHost.run()`).
signal played(result: MiniGameResult)

const PICKER_SCENE := preload("res://tiamat/core/minigames/minigame_picker.tscn")

## The minigame interact plays, when the station offers no `choices`.
@export var minigame_id: StringName
## The minigames the player picks from, in the order listed; each needs a
## display name. Empty: interact plays `minigame_id`.
@export var choices: Array[StringName] = []
## The heading of the list of `choices`; empty: "Choose".
@export var title := ""
## Settings over the minigame's own (`MiniGameDefinition.settings`).
@export var context: Dictionary = {}

@onready var interactable: Interactable = $Interactable

var _picker: MiniGamePicker

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

## Runs `minigame` (`minigame_id` when empty) and gives how it went.
func play(minigame := &"") -> MiniGameResult:
	var result: MiniGameResult = await MiniGameHost.run(minigame if minigame != &"" else minigame_id, context)
	played.emit(result)
	return result

## Lists the `choices` and gives the one the player picks, or &"" when they
## close the list.
func pick() -> StringName:
	if _picker == null:
		_picker = PICKER_SCENE.instantiate() as MiniGamePicker
		add_child(_picker)
	_picker.open(choices, title)
	var picked: StringName = await _picker.picked
	return picked

## The list `pick()` shows, or null before it first shows.
func get_picker() -> MiniGamePicker:
	return _picker

func _on_interacted(_actor: Node) -> void:
	if choices.is_empty():
		play()
		return
	var picked: StringName = await pick()
	if picked != &"":
		play(picked)

## The station's minigames must be of `registry`, and each of its choices
## needs a name to be picked by; the registry adds the location it stands in
## to each problem.
func find_scene_problems(registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	if choices.is_empty():
		if not registry.has_entry(MiniGameDefinition.KIND, minigame_id):
			problems.append("station '%s' runs unknown minigame '%s'" % [name, minigame_id])
		return problems
	for choice: StringName in choices:
		var definition := registry.get_entry(MiniGameDefinition.KIND, choice) as MiniGameDefinition
		if definition == null:
			problems.append("station '%s' offers unknown minigame '%s'" % [name, choice])
		elif definition.display_name.is_empty():
			problems.append("station '%s' offers minigame '%s', which has no display name" % [name, choice])
	return problems
