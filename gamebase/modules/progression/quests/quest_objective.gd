class_name QuestObjective
extends Resource

## One thing a quest asks of the player, counted from an event of any module
## (`GameEvent`): every crop harvested, the turnips among them, a talk with
## one NPC. The quest manager adds to it each time `event` fires and
## `condition` holds, one or the event's `count_per` argument, until it
## reaches `required_amount`. With a `measure`, it follows a number instead
## (the deepest mine floor reached), read when the quest starts and each time
## the event fires.

## The objective as the player reads it ("Catch a trout"); a quest of one
## objective may leave it to the quest's description.
@export var description: String
## The event that moves the objective on, a signal of an autoload written
## `<Autoload>.<signal>` (`LifesimEvents.crop_harvested`).
@export var event: StringName
## What must hold when the event fires for it to count, in the `GameQuery`
## syntax, reading the event's arguments by name (`EVENT_ARG crop_id turnip`,
## `ITEM_TAG $item_id fish`); empty counts every time.
@export var condition: String = ""
## The integer argument of the event that says how many it counts
## (`quantity`); empty counts one each time.
@export var count_per: StringName
## The number the objective follows instead of counting, a method of an
## autoload written `<Autoload>.<method>` that takes no argument and returns an
## int (`MineState.get_deepest_floor`).
@export var measure: StringName
@export_range(1, 9999, 1) var required_amount := 1

## How much the event with `args` (by name) adds to the objective: 0 when its
## condition does not hold.
func count(args: Dictionary) -> int:
	if not GameRules.check(condition, {"event": args}):
		return 0
	return 1 if count_per == &"" else maxi(int(args.get(String(count_per), 0)), 0)

## The number `measure` reads now; 0 when it cannot be read.
func read_measure() -> int:
	var source := _measure_source()
	if source == null:
		return 0
	var value: Variant = source.call(String(measure).get_slice(".", 1))
	return int(value) if value is int else 0

## What is wrong with the objective, each problem a phrase.
func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := GameEvent.find_problems(event, PackedStringArray([condition]), registry)
	if required_amount < 1:
		problems.append("requires %d; an objective requires at least 1" % required_amount)
	if GameEvent.find_source(event) == null:
		return problems
	var args := GameEvent.get_args(event)
	if count_per != &"" and int(args.get(String(count_per), TYPE_NIL)) != TYPE_INT:
		problems.append("counts per '%s', which is no integer argument of '%s'" % [count_per, event])
	if measure != &"":
		if count_per != &"":
			problems.append("follows '%s', so it counts per nothing" % measure)
		if _measure_source() == null:
			problems.append("follows '%s', which is no method of an autoload that takes no argument and returns an int (<Autoload>.<method>)" % measure)
	return problems

# The autoload whose method `measure` names, when the method takes no argument
# and returns an int; otherwise null.
func _measure_source() -> Node:
	var parts := String(measure).split(".")
	var tree := Engine.get_main_loop() as SceneTree
	if parts.size() != 2 or tree == null:
		return null
	var source := tree.root.get_node_or_null(NodePath(parts[0]))
	if source == null:
		return null
	for method: Dictionary in source.get_method_list():
		if method["name"] == parts[1]:
			var returns := int((method["return"] as Dictionary)["type"])
			var required := (method["args"] as Array).size() - (method["default_args"] as Array).size()
			return source if returns == TYPE_INT and required == 0 else null
	return null
