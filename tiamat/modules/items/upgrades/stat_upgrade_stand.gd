class_name StatUpgradeStand
extends Node2D

## Something in the world where the player buys lasting upgrades
## (`StatUpgradeData`) level by level: a forge, a trainer. It lists its
## upgrades (`ChoiceMenu`), each with its level, what it does and what its
## next level costs, or why the player cannot buy it, and buys the one picked;
## the list stays open for the next until the player closes it. With the
## `Interactable` child the stand needs; a game draws the stand itself, as
## children of its instance of `stat_upgrade_stand.tscn`.

## The player bought level `level` of upgrade `upgrade_id` here.
signal upgrade_bought(upgrade_id: StringName, level: int)

## The ids of the upgrades it offers; empty, every one of the game's.
@export var upgrade_ids: Array[StringName] = []
## The heading of the list; empty: "Upgrades".
@export var title := ""

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

## The upgrades it offers, in the order it lists them.
func get_upgrades() -> Array[StatUpgradeData]:
	if upgrade_ids.is_empty():
		return StatUpgradeData.find_all()
	var upgrades: Array[StatUpgradeData] = []
	for upgrade_id: StringName in upgrade_ids:
		var upgrade := StatUpgradeData.find(upgrade_id)
		if upgrade != null:
			upgrades.append(upgrade)
	return upgrades

## The list it shows, or null before it first showed it.
func get_choice_menu() -> ChoiceMenu:
	return ChoiceMenu.of(self)

## Lists its upgrades until the player closes the list, buying each one they
## pick; gives how many levels they bought.
func browse() -> int:
	var bought := 0
	var focus := &""
	while true:
		var choices: Array[ChoiceMenu.Choice] = []
		for upgrade: StatUpgradeData in get_upgrades():
			choices.append(choice_of(upgrade))
		if choices.is_empty():
			GameEvents.toast("Nothing to upgrade here")
			return bought
		var picked: StringName = await ChoiceMenu.ask(self, choices, title if not title.is_empty() else "Upgrades", focus)
		if picked == &"":
			return bought
		focus = picked
		var upgrade := StatUpgradeData.find(picked)
		if upgrade == null or not upgrade.buy():
			continue
		bought += 1
		GameEvents.toastf("%s is now level %d", [upgrade.get_display_name(), upgrade.get_level()])
		upgrade_bought.emit(picked, upgrade.get_level())
	return bought

## The choice a list offers of `upgrade`: its name and level, and under it
## what it does and what its next level costs, or why the player cannot buy
## it, which locks it.
static func choice_of(upgrade: StatUpgradeData) -> ChoiceMenu.Choice:
	var text := TranslationServer.translate("%s (level %d of %d)") % [upgrade.get_display_name(), upgrade.get_level(), upgrade.max_level]
	var lines := PackedStringArray()
	if not upgrade.description.is_empty():
		lines.append(TranslationServer.translate(upgrade.description))
	var problem := upgrade.get_buy_problem()
	if not problem.is_empty():
		lines.append(problem)
	elif not upgrade.describe_cost().is_empty():
		lines.append(TranslationServer.translate("Next level: %s") % upgrade.describe_cost())
	return ChoiceMenu.Choice.new(upgrade.id, text, "\n".join(lines), problem.is_empty())

## What is wrong with the stand in a scene: an upgrade it names that the
## game's content does not hold.
func find_scene_problems(registry: ContentRegistry, _location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	for upgrade_id: StringName in upgrade_ids:
		if registry.get_entry(StatUpgradeData.KIND, upgrade_id) == null:
			problems.append("upgrade stand '%s' offers unknown upgrade '%s'" % [name, upgrade_id])
	return problems

func _on_interacted(_actor: Node) -> void:
	browse()
