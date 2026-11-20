class_name MiniGameStation
extends Node2D

## Something in the world the player uses to play a minigame
## (`MiniGameDefinition`): a war table, an arcade cabinet, a card table. With
## the `Interactable` child the station needs, interact runs `minigame_id`
## through `MiniGameHost`, with `context` over the minigame's own settings, and
## `played` says how it went. A station that offers several minigames lists
## its `choices` for the player to pick from first (a `ChoiceMenu`): a
## campaign's battles, each by its name, marked once won, with its description
## and the player's best score under it, and locked while its condition does
## not hold (`MINIGAME_WON ford_battle`), saying what it needs. A game draws the station itself, as children
## of its instance of `minigame_station.tscn`.

## The minigame ended, or could not start (`MiniGameHost.run()`).
signal played(result: MiniGameResult)

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
	var offered: Array[ChoiceMenu.Choice] = []
	for choice: StringName in choices:
		var definition := MiniGameDefinition.find(choice)
		if definition != null:
			offered.append(choice_of(definition))
	var picked: StringName = await ChoiceMenu.ask(self, offered, title)
	return picked

## The list `pick()` shows, or null before it first shows.
func get_picker() -> ChoiceMenu:
	return ChoiceMenu.of(self)

## The choice a list offers of `definition`: its name, marked once won in this
## save, and under it its description and the player's best score, or, while
## its condition does not hold, what it needs, the choice then locked.
static func choice_of(definition: MiniGameDefinition) -> ChoiceMenu.Choice:
	var name: String = TranslationServer.translate(definition.display_name) if not definition.display_name.is_empty() else String(definition.id)
	var text: String = TranslationServer.translate("%s (Won)") % name if definition.get_wins() > 0 else name
	if not definition.is_open():
		var needs := definition.get_requirements()
		var locked: String = TranslationServer.translate("Locked: %s") % ", ".join(needs) if not needs.is_empty() else TranslationServer.translate("Locked")
		return ChoiceMenu.Choice.new(definition.id, text, locked, false)
	var lines := PackedStringArray()
	if not definition.description.is_empty():
		lines.append(TranslationServer.translate(definition.description))
	if not definition.score_name.is_empty() and definition.get_best_score() > 0:
		lines.append(TranslationServer.translate("Best %s: %d") % [TranslationServer.translate(definition.score_name), definition.get_best_score()])
	return ChoiceMenu.Choice.new(definition.id, text, "\n".join(lines))

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
