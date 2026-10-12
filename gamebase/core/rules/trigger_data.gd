class_name TriggerData
extends ContentEntry

## What content does when something happens: when `event` fires and
## `condition` holds, `GameTriggers` runs `actions`. Story beats, rewards for
## what the player does and achievements are triggers instead of code, so a
## game wires its modules together in data.

const KIND := &"trigger"

## The event, a signal of an autoload written `<Autoload>.<signal>`
## (`LifesimEvents.crop_harvested`).
@export var event: StringName
## What must hold when the event fires, in the `GameQuery` syntax; empty means
## always. `EVENT_ARG` and `EVENT_ARG_AT_LEAST` read the event's arguments by
## name (`EVENT_ARG_AT_LEAST quantity 3`), and here and in `actions` an
## argument written `$name` is the event's argument (`ADD_MONEY $price`).
@export var condition: String = ""
## What the trigger does, in order (`GameRules.run_actions()`); an action
## that fails stops the ones after it.
@export var actions: PackedStringArray = PackedStringArray()
## An integer argument of the event to run the actions once per unit of
## (`quantity`: once per crop harvested); empty runs them once.
@export var repeat_per: StringName
## Whether the trigger fires only once in a world: once all its actions ran.
## An action that failed (a full inventory) leaves it to fire again, from that
## action: the ones before it ran and stay done. It cannot repeat per an
## argument, which would make how much it gives depend on the retry.
@export var once := false

## The trigger with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> TriggerData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as TriggerData

## The running game's triggers, sorted by id.
static func find_all() -> Array[TriggerData]:
	var result: Array[TriggerData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## The autoload that emits `event`, or null when there is none.
func get_source() -> Node:
	var parts := String(event).split(".")
	var tree := Engine.get_main_loop() as SceneTree
	if parts.size() != 2 or tree == null:
		return null
	var source := tree.root.get_node_or_null(NodePath(parts[0]))
	return source if source != null and source.has_signal(parts[1]) else null

## The event's arguments, name -> type, in their order; empty when the event
## does not exist.
func get_event_args() -> Dictionary:
	var result: Dictionary = {}
	var source := get_source()
	if source == null:
		return result
	var signal_name := String(event).get_slice(".", 1)
	for info: Dictionary in source.get_signal_list():
		if info["name"] == signal_name:
			for arg: Dictionary in info["args"]:
				result[String(arg["name"])] = int(arg["type"])
	return result

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if get_source() == null:
		problems.append("listens to '%s', which is no signal of an autoload (<Autoload>.<signal>)" % event)
		return problems
	if actions.is_empty():
		problems.append("has no actions")
	var args := get_event_args()
	if repeat_per != &"" and int(args.get(String(repeat_per), TYPE_NIL)) != TYPE_INT:
		problems.append("repeats per '%s', which is no integer argument of '%s'" % [repeat_per, event])
	if once and repeat_per != &"":
		problems.append("fires once, so it cannot repeat per '%s'" % repeat_per)
	var texts := actions.duplicate()
	texts.append(condition)
	for use: Dictionary in GameRulesService.find_event_arg_uses(texts):
		var name: String = use["name"]
		var problem := ""
		if not args.has(name):
			problem = "reads argument '%s', which '%s' does not have" % [name, event]
		else:
			# The name EVENT_ARG_AT_LEAST reads compares as a number.
			var kind := GameRules.get_arg_kind(use["key"], use["index"]) if int(use["index"]) >= 0 \
				else (GameRulesService.ARG_NUMBER if use["key"] == &"EVENT_ARG_AT_LEAST" else GameRulesService.ARG_TEXT)
			if not GameRulesService.takes_type(kind, args[name]):
				problem = "passes argument '%s' (%s) to %s, which takes %s" % [name, type_string(args[name]), use["key"], kind]
		if not problem.is_empty() and not problems.has(problem):
			problems.append(problem)
	return problems
