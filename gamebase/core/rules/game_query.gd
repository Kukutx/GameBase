class_name GameQuery
extends RefCounted

## Parses the text of a condition query or an action list.
##
## A query is a comma-separated list of clauses that must all be true:
##
##     WORLD_FLAG project:starter_garden:complete, !QUEST_COMPLETED first_harvest
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
