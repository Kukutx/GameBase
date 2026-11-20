class_name DepthEntrance
extends InteractivePortal

## The way down from camp: starts a new run (`DepthRun.start_run()`) and takes
## the player to its first depth. Once the world reached a shortcut
## (`DepthRun.get_shortcuts()`), it asks first where the run starts
## (`ChoiceMenu`), the deepest shortcut first. Once a pact may be made (the
## roguelite module's boons of the pool `PACT_POOL` whose condition holds:
## after the first run), it asks then whether the run starts under one, a
## burden with a reward that lasts the run.

## The pool of boons that are pacts (`BoonData.pool`).
const PACT_POOL := &"pact"
## The choice of starting under no pact.
const NO_PACT := &"no_pact"

var _start_depth := 1
var _pact := NO_PACT

func _ready() -> void:
	super()
	about_to_travel.connect(func() -> void: begin_run(_start_depth, _pact))

## The depth the player starts the run at: the first while the world has no
## shortcut, else the one they pick; 0 when they close the list.
func choose_start() -> int:
	var shortcuts := DepthRun.get_shortcuts()
	if shortcuts.size() <= 1:
		return 1
	var choices: Array[ChoiceMenu.Choice] = []
	for depth: int in shortcuts:
		var note := tr("A new run from the top") if depth == 1 else tr("Skips the first %d depths") % (depth - 1)
		choices.append(ChoiceMenu.Choice.new(StringName(str(depth)), tr("Depth %d") % depth, note))
	var deepest := StringName(str(shortcuts[shortcuts.size() - 1]))
	var picked: StringName = await ChoiceMenu.ask(self, choices, "Where to Start", deepest)
	return int(String(picked)) if picked != &"" else 0

## The pacts the player may make now, in the order of their ids.
func get_pacts() -> Array[BoonData]:
	var pacts: Array[BoonData] = []
	pacts.assign(BoonData.find_pool(PACT_POOL).filter(func(pact: BoonData) -> bool: return GameRules.check(pact.condition)))
	return pacts

## The pact the player starts the run under: `NO_PACT` when none may be made
## yet or they choose none, &"" when they close the list.
func choose_pact() -> StringName:
	var pacts := get_pacts()
	if pacts.is_empty():
		return NO_PACT
	var choices: Array[ChoiceMenu.Choice] = [ChoiceMenu.Choice.new(NO_PACT, tr("No Pact"), tr("The depths as they are"))]
	for pact: BoonData in pacts:
		choices.append(BoonAltar.choice_of(pact))
	return await ChoiceMenu.ask(self, choices, "Make a Pact?", NO_PACT)

func _on_interacted(_actor: Node) -> void:
	var depth: int = await choose_start()
	if depth <= 0:
		return
	var pact: StringName = await choose_pact()
	if pact == &"":
		return
	_start_depth = depth
	_pact = pact
	take()

## Starts the run at `depth` (`DepthRun.start_run()`) under pact `pact`, or
## under none (`NO_PACT`), as the player goes down.
func begin_run(depth: int, pact: StringName) -> void:
	DepthRun.start_run(depth)
	if pact != NO_PACT:
		RunState.take_boon(pact)
