class_name BoonAltar
extends Node2D

## Something in the world where the player picks a boon (`BoonData`) for the
## run: it lists the boons the run offers there (`RunService.offer_boons()`,
## `count` of them, rolled from the run's stream that `key` names, so leaving
## and coming back offers the same) for the player to take one (`ChoiceMenu`).
## An altar gives one boon a run; once taken, it is spent (`is_spent()`) and
## takes no more. With the `Interactable` child the altar needs; a game draws
## the altar itself, as children of its instance of `boon_altar.tscn`, and
## sets `key` where one scene stands for many places (a depth: "depth3").

## The player took `boon_id` here.
signal boon_taken(boon_id: StringName)

## How many boons the altar offers.
@export_range(1, 6, 1) var count := 3
## The heading of the list; empty: "Choose a Boon".
@export var title := ""
## Names the altar in the run: its offer, and whether it is spent. Empty: the
## altar's node name.
@export var key := ""
## The pool of boons it offers (`BoonData.pool`); empty, the common one.
@export var pool: StringName

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	refresh()

## What names the altar in the run.
func get_key() -> String:
	return key if not key.is_empty() else String(name)

## Whether the player took a boon here in this run.
func is_spent() -> bool:
	return RunState.get_value(_spent_key(), false) == true

## The boons the altar offers now: none once spent.
func get_offer() -> Array[BoonData]:
	if is_spent():
		return [] as Array[BoonData]
	return RunState.offer_boons(count, get_key(), pool)

## Lists the boons offered and gives the one the player took, or &"" when
## they closed the list or the altar offers none.
func choose() -> StringName:
	var offer := get_offer()
	if offer.is_empty():
		GameEvents.toast("The altar is cold")
		return &""
	var choices: Array[ChoiceMenu.Choice] = []
	for boon: BoonData in offer:
		choices.append(choice_of(boon))
	var picked: StringName = await ChoiceMenu.ask(self, choices, title if not title.is_empty() else "Choose a Boon")
	if picked == &"" or is_spent() or not RunState.take_boon(picked):
		return &""
	RunState.set_value(_spent_key(), true)
	refresh()
	GameEvents.toastf("%s taken", [BoonData.find(picked).display_name])
	boon_taken.emit(picked)
	return picked

## The choice a list offers of `boon`: its name, and under it its
## description, what it changes (`GameStats.describe_changes()`: "Attack
## +25%, Max health -40") and, once the run took it, how many times of how
## many it may (only how many for one it may take `BoonData.UNLIMITED` times).
static func choice_of(boon: BoonData) -> ChoiceMenu.Choice:
	var lines := PackedStringArray()
	if not boon.description.is_empty():
		lines.append(TranslationServer.translate(boon.description))
	var changes := GameStats.describe_changes(boon.multipliers, boon.bonuses)
	if not changes.is_empty():
		lines.append(GameText.list(changes))
	var stacks := boon.get_stacks()
	if stacks > 0 and boon.max_stacks >= BoonData.UNLIMITED:
		lines.append(TranslationServer.translate("Taken %d") % stacks)
	elif stacks > 0:
		lines.append(TranslationServer.translate("Taken %d of %d") % [stacks, boon.max_stacks])
	return ChoiceMenu.Choice.new(boon.id, boon.get_display_name(), "\n".join(lines))

## Takes no more once spent, nor while no run goes on.
func refresh() -> void:
	if interactable != null:
		interactable.enabled = RunState.is_active() and not is_spent()

func _on_interacted(_actor: Node) -> void:
	choose()

func _spent_key() -> StringName:
	return StringName("altar:%s" % get_key())
