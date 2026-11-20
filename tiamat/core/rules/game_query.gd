class_name GameQuery
extends RefCounted

## Parses the text of a condition query or an action list.
##
## A query is a comma-separated list of clauses that must all be true:
##
##     WORLD_FLAG gate:open, !DAY_AT_LEAST 10, MONEY_AT_LEAST 500
##
## A clause is a key followed by space-separated arguments; `!` before the key
## negates it, and an argument containing spaces or commas is written in double
## quotes. `ANY "<query>" "<query>" ...` is true when one of its quoted queries
## is. An empty query is always true.
##
## An action list uses the same clause syntax without negation; each clause is
## one action, run in order.

## Parses `text` into {"clauses": Array[Dictionary], "error": String}. Each
## clause is {"key": StringName, "args": PackedStringArray, "negate": bool}.
static func parse(text: String) -> Dictionary:
	var clauses: Array[Dictionary] = []
	var split := _split_top_level(text, ",")
	if not String(split["error"]).is_empty():
		return {"clauses": clauses, "error": split["error"]}
	for raw_clause: String in split["parts"]:
		var clause_text := raw_clause.strip_edges()
		if clause_text.is_empty():
			if split["parts"].size() > 1:
				return {"clauses": clauses, "error": "empty clause in '%s'" % text}
			continue
		var negate := clause_text.begins_with("!")
		if negate:
			clause_text = clause_text.substr(1).strip_edges()
		var tokens := _split_top_level(clause_text, " ")
		if not String(tokens["error"]).is_empty():
			return {"clauses": clauses, "error": tokens["error"]}
		var words := PackedStringArray()
		for token: String in tokens["parts"]:
			if not token.is_empty():
				words.append(_unquote(token))
		if words.is_empty():
			return {"clauses": clauses, "error": "missing key after '!' in '%s'" % text}
		clauses.append({
			"key": StringName(words[0].to_upper()),
			"args": words.slice(1),
			"negate": negate,
		})
	return {"clauses": clauses, "error": ""}

## The arguments of each `key` clause in the actions of `registry`'s content:
## every entry's `actions` and `…_actions` texts, and those of the resources
## it holds, as `GameRules.validate_content()` reads them (the items every
## ADD_ITEM gives, `ItemSources`).
static func find_action_args(registry: ContentRegistry, key: StringName) -> Array[PackedStringArray]:
	var found: Array[PackedStringArray] = []
	for kind: StringName in registry.get_kinds():
		for entry: Variant in registry.get_entries(kind):
			if entry is Resource:
				_find_action_args(entry as Resource, StringName(String(key).to_upper()), found, 0)
	return found

static func _find_action_args(resource: Resource, key: StringName, found: Array[PackedStringArray], depth: int) -> void:
	if depth > 4:
		return
	for property: Dictionary in resource.get_property_list():
		if not int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			continue
		var name := String(property["name"])
		var value: Variant = resource.get(name)
		if (name == "actions" or name.ends_with("_actions")) and (value is PackedStringArray or value is Array):
			for text: Variant in value:
				for clause: Dictionary in parse(String(text))["clauses"]:
					if clause["key"] == key:
						found.append(clause["args"])
		elif value is Array:
			for item: Variant in value:
				if item is Resource and not (item as Resource).resource_path.ends_with(".tres"):
					_find_action_args(item as Resource, key, found, depth + 1)

## Splits on `separator` outside double quotes; quotes are kept on the parts.
static func _split_top_level(text: String, separator: String) -> Dictionary:
	var parts: Array[String] = []
	var current := ""
	var quoted := false
	for character: String in text:
		if character == "\"":
			quoted = not quoted
			current += character
		elif character == separator and not quoted:
			parts.append(current)
			current = ""
		else:
			current += character
	if quoted:
		return {"parts": parts, "error": "unterminated quote in '%s'" % text}
	parts.append(current)
	return {"parts": parts, "error": ""}

static func _unquote(token: String) -> String:
	if token.length() >= 2 and token.begins_with("\"") and token.ends_with("\""):
		return token.substr(1, token.length() - 2)
	return token
