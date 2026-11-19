class_name TriggerData
extends ContentEntry

## What content does when something happens: when `event` fires and
## `condition` holds, `GameTriggers` runs `actions`. Story beats, rewards for
## what the player does and achievements are triggers instead of code, so a
## game wires its modules together in data.

const KIND := &"trigger"

## The event, a signal of an autoload written `<Autoload>.<signal>`
## (`LifesimEvents.crop_harvested`; see `GameEvent`).
@export var event: StringName
## What must hold when the event fires, in the `GameQuery` syntax; empty means
## always. `EVENT_ARG` and `EVENT_ARG_AT_LEAST` read the event's arguments by
## name (`EVENT_ARG crop_id turnip`, `EVENT_ARG_AT_LEAST quantity 3`), and
## here and in `actions` an argument written `$name` is the event's argument
## (`ADD_MONEY $price`).
@export var condition: String = ""
## What the trigger does, in order (`GameRules.run_actions()`); an action
## that fails stops the ones after it.
@export var actions: PackedStringArray = PackedStringArray()
## An integer argument of the event to run the actions once per unit of
## (`quantity`: once per crop harvested); empty runs them once.
@export var repeat_per: StringName
## Whether the trigger fires only once in a world: once all its actions ran.
## An action that failed (a full inventory) after others ran leaves it
## pending: the next time the event fires, it resumes at that action with the
## arguments of the event that set it off and without checking the condition
## again, so the ones before it are not given twice. One whose first action
## failed gave nothing and fires anew. It cannot repeat per an argument, which
## would make how much it gives depend on the retry, and its event declares
## only what a save keeps: booleans, numbers, text and positions.
@export var once := false

## The trigger with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> TriggerData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as TriggerData

## The running game's triggers, sorted by id.
static func find_all() -> Array[TriggerData]:
	var result: Array[TriggerData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var texts := actions.duplicate()
	texts.append(condition)
	var problems := GameEvent.find_problems(event, texts, registry)
	if GameEvent.find_source(event) == null:
		return problems
	if GameRules.count_actions(actions) == 0:
		problems.append("has no actions")
	var args := GameEvent.get_args(event)
	if repeat_per != &"" and int(args.get(String(repeat_per), TYPE_NIL)) != TYPE_INT:
		problems.append("repeats per '%s', which is no integer argument of '%s'" % [repeat_per, event])
	if once and repeat_per != &"":
		problems.append("fires once, so it cannot repeat per '%s'" % repeat_per)
	if once:
		for name: String in args:
			var type := int(args[name])
			if not GameTriggerService.SAVED_TYPES.has(type):
				problems.append("fires once, so a save may keep its event's arguments, and '%s' is %s; an event of a once trigger declares booleans, numbers, text or positions" % [name, "untyped" if type == TYPE_NIL else "of type " + type_string(type)])
	return problems
