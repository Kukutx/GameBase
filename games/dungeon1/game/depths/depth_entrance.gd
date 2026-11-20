class_name DepthEntrance
extends InteractivePortal

## The way down from camp: starts a new run (`DepthRun.start_run()`) and takes
## the player to its first depth. Once the world reached a shortcut
## (`DepthRun.get_shortcuts()`), it asks first where the run starts
## (`ChoiceMenu`), the deepest shortcut first.

var _start_depth := 1

func _ready() -> void:
	super()
	about_to_travel.connect(func() -> void: DepthRun.start_run(_start_depth))

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

func _on_interacted(_actor: Node) -> void:
	var depth: int = await choose_start()
	if depth > 0:
		_start_depth = depth
		take()
