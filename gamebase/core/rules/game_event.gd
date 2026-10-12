class_name GameEvent
extends RefCounted

## An event content listens to: a signal of an autoload, written
## `<Autoload>.<signal>` (`LifesimEvents.crop_harvested`). A trigger runs its
## actions when one fires (`TriggerData.event`) and a quest objective counts
## it (`QuestObjective.event`); either reads the signal's arguments by name in
## its condition (`EVENT_ARG crop_id turnip`), and a trigger in its actions
## too (`$quantity`). `GameEventListener` listens to one.
##
## An argument named `<kind>_id`, or `<something>_<kind>_id`, holds the id of
## an entry of that kind of content when an installed module registers the kind
## (`item_id`, `crop_id`, `mining_node_id`, `result_item_id`), so content checks the ids a condition compares it with
## and the keys it is passed to. A module names the arguments of its events
## that way.

## The autoload that emits `event`, or null when there is none.
static func find_source(event: StringName) -> Node:
	var parts := String(event).split(".")
	var tree := Engine.get_main_loop() as SceneTree
	if parts.size() != 2 or tree == null:
		return null
	var source := tree.root.get_node_or_null(NodePath(parts[0]))
	return source if source != null and source.has_signal(parts[1]) else null

## The event's arguments, name -> Variant.Type, in their order; empty when the
## event does not exist.
static func get_args(event: StringName) -> Dictionary:
	var result: Dictionary = {}
	var source := find_source(event)
	if source == null:
		return result
	var signal_name := String(event).get_slice(".", 1)
	for info: Dictionary in source.get_signal_list():
		if info["name"] == signal_name:
			for arg: Dictionary in info["args"]:
				result[String(arg["name"])] = int(arg["type"])
	return result

## The kind of content an argument called `name` holds an id of in `registry`,
## or an empty name: `<kind>_id` names an id of that kind (`crop` for
## `crop_id`), and so does a name that ends in `_<kind>_id`
## (`item` for `result_item_id`); the longest kind wins.
static func get_arg_content_kind(name: String, registry: ContentRegistry) -> StringName:
	if not name.ends_with("_id"):
		return &""
	var stem := name.trim_suffix("_id")
	var found := &""
	for kind: StringName in registry.get_kinds():
		var named := stem == String(kind) or stem.ends_with("_" + String(kind))
		if named and String(kind).length() > String(found).length():
			found = kind
	return found

## Whether `resource` listens to an event, as a trigger and a quest objective
## do: it has an `event`. Only such content reads event arguments.
static func is_listener(resource: Resource) -> bool:
	return resource.get("event") is StringName

## Each place `texts`, conditions or actions, read an argument of the event
## their content listens to, as {"name", "key", "index", "values"}:
## `index` is where the `$name` stands among the key's arguments, or -1 for the
## name `EVENT_ARG` and `EVENT_ARG_AT_LEAST` read, with the values they compare
## it with. The clauses inside `ANY` count too.
static func find_arg_uses(texts: PackedStringArray) -> Array[Dictionary]:
	var uses: Array[Dictionary] = []
	for text: String in texts:
		for clause: Dictionary in GameQuery.parse(text)["clauses"]:
			var key := StringName(String(clause["key"]).to_upper())
			var args: PackedStringArray = clause["args"]
			if key == &"ANY":
				uses.append_array(find_arg_uses(args))
				continue
			if (key == &"EVENT_ARG" or key == &"EVENT_ARG_AT_LEAST") and not args.is_empty():
				uses.append({"name": args[0], "key": key, "index": -1, "values": args.slice(1)})
			for index: int in args.size():
				if args[index].begins_with("$"):
					uses.append({"name": args[index].substr(1), "key": key, "index": index, "values": PackedStringArray()})
	return uses

## What is wrong with content that listens to `event` and reads its arguments
## in `texts`, conditions and actions: the event is no signal of an autoload,
## or a text reads an argument the event does not have, passes one to a key
## that takes another type or kind of content, or compares an id argument with
## an id its kind has no entry for. Each problem a phrase after the content's
## kind and id.
static func find_problems(event: StringName, texts: PackedStringArray, registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if find_source(event) == null:
		problems.append("listens to '%s', which is no signal of an autoload (<Autoload>.<signal>)" % event)
		return problems
	var args := get_args(event)
	for use: Dictionary in find_arg_uses(texts):
		var name: String = use["name"]
		var problem := ""
		if not args.has(name):
			problem = "reads argument '%s', which '%s' does not have" % [name, event]
		else:
			problem = _find_use_problem(use, int(args[name]), get_arg_content_kind(name, registry), registry)
		if not problem.is_empty() and not problems.has(problem):
			problems.append(problem)
	return problems

# What is wrong with one use of an event argument of the Variant `type` that
# holds an id of `content_kind` (or none), or "".
static func _find_use_problem(use: Dictionary, type: int, content_kind: StringName, registry: ContentRegistry) -> String:
	var name: String = use["name"]
	var key: StringName = use["key"]
	var index := int(use["index"])
	if index < 0:
		# The name EVENT_ARG_AT_LEAST reads compares as a number, and the
		# values EVENT_ARG compares an id with are ids of its kind.
		if key == &"EVENT_ARG_AT_LEAST" and not GameRulesService.takes_type(GameRulesService.ARG_NUMBER, type):
			return "passes argument '%s' (%s) to %s, which takes %s" % [name, type_string(type), key, GameRulesService.ARG_NUMBER]
		if key == &"EVENT_ARG" and content_kind != &"":
			for value: String in use["values"]:
				if not registry.has_entry(content_kind, StringName(value)):
					return "compares argument '%s' with unknown %s '%s'" % [name, ContentRegistry.get_kind_label(content_kind), value]
		return ""
	var kind := GameRules.get_arg_kind(key, index)
	if not GameRulesService.takes_type(kind, type):
		return "passes argument '%s' (%s) to %s, which takes %s" % [name, type_string(type), key, kind]
	if content_kind != &"" and registry.get_kinds().has(kind) and kind != content_kind:
		return "passes argument '%s' (%s id) to %s, which takes %s" % [name, ContentRegistry.get_kind_label(content_kind), key, ContentRegistry.get_kind_label(kind)]
	return ""
