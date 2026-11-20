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
## An altar may let the player reroll its offer for another (`rerolls` times a
## run), at a price (`reroll_condition`, `reroll_actions`: Ember Depths' 30
## coins), from a stream of its own for each reroll, so the same run and the
## same rerolls offer the same.

## The player took `boon_id` here.
signal boon_taken(boon_id: StringName)
## The player rerolled the offer (`reroll()`).
signal rerolled

## The id of the choice that rerolls the offer.
const REROLL := &"__reroll"

## How many boons the altar offers.
@export_range(1, 6, 1) var count := 3
## The heading of the list; empty: "Choose a Boon".
@export var title := ""
## Names the altar in the run: its offer, and whether it is spent. Empty: the
## altar's node name.
@export var key := ""
## The pool of boons it offers (`BoonData.pool`); empty, the common one.
@export var pool: StringName
## How many times a run may reroll the offer here for another; 0: never.
@export_range(0, 9, 1) var rerolls := 0
## What a reroll needs (a `GameRules` query, whose description the choice
## shows: "30g"); empty, nothing.
@export var reroll_condition := ""
## What a reroll takes (`GameRules` actions, run once the condition holds:
## "SPEND_MONEY 30"); empty, nothing.
@export var reroll_actions := PackedStringArray()

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
	var times := _rerolled()
	return RunState.offer_boons(count, get_key() if times == 0 else "%s#%d" % [get_key(), times], pool)

## How many more times the run may reroll the offer here.
func get_rerolls_left() -> int:
	return maxi(rerolls - _rerolled(), 0)

## Whether the player may reroll the offer now: the altar is not spent, a
## reroll is left and its condition holds.
func can_reroll() -> bool:
	return RunState.is_active() and not is_spent() and get_rerolls_left() > 0 and GameRules.check(reroll_condition)

## Takes the reroll's price and rerolls the offer; false, and nothing changes,
## when the player may not (`can_reroll()`) or its actions fail.
func reroll() -> bool:
	if not can_reroll() or not GameRules.run_actions(reroll_actions):
		return false
	RunState.set_value(_rerolls_key(), _rerolled() + 1)
	rerolled.emit()
	return true

## Lists the boons offered, and the reroll when the altar has one, and gives
## the boon the player took, or &"" when they closed the list or the altar
## offers none; a reroll lists the new offer.
func choose() -> StringName:
	var picked := REROLL
	while picked == REROLL:
		var offer := get_offer()
		if offer.is_empty():
			GameEvents.toast("The altar is cold")
			return &""
		var choices: Array[ChoiceMenu.Choice] = []
		for boon: BoonData in offer:
			choices.append(choice_of(boon))
		if rerolls > 0:
			choices.append(_reroll_choice())
		picked = await ChoiceMenu.ask(self, choices, title if not title.is_empty() else "Choose a Boon")
		if picked == REROLL and not reroll():
			return &""
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

func _rerolls_key() -> StringName:
	return StringName("altar_rerolls:%s" % get_key())

func _rerolled() -> int:
	return int(RunState.get_value(_rerolls_key(), 0))

# The choice that rerolls the offer: its price and how many rerolls are left.
func _reroll_choice() -> ChoiceMenu.Choice:
	var lines := GameRules.describe(reroll_condition)
	lines.append(TranslationServer.translate("%d left") % get_rerolls_left())
	return ChoiceMenu.Choice.new(REROLL, TranslationServer.translate("Reroll"), GameText.list(lines), can_reroll())
