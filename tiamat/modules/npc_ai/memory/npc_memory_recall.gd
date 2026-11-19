class_name NpcMemoryRecall
extends RefCounted

## Which of an NPC's remembered messages (`NpcMemory`) bear on what the player
## says now: those that share the most words with it, a word counting more the
## fewer messages hold it, and the later message first among equals. A chat
## puts them in what it asks a language model (`NpcAiPrompt`), beside the
## latest messages, so an NPC can bring up a talk from days ago.
##
## Words are runs of letters or digits, lowercased, of two characters or more
## and not among the commonest English ones; text in Chinese, Japanese or
## Korean, which puts no spaces between words, counts each pair of neighbouring
## characters as a word, and a character on its own as one.

# Words too common in what a player says to tell one talk from another.
const _COMMON := {
	"the": true, "and": true, "or": true, "to": true, "of": true, "in": true,
	"on": true, "at": true, "is": true, "are": true, "was": true, "it": true,
	"me": true, "my": true, "you": true, "your": true, "do": true, "what": true,
	"how": true, "about": true, "any": true, "an": true, "be": true, "for": true,
}
# A share of a word's weight the latest message gets over the oldest.
const _RECENCY_WEIGHT := 0.1

static var _cjk_runs: RegEx
static var _word_runs: RegEx

## The words of `text`, in order and with repeats.
static func words(text: String) -> PackedStringArray:
	if _cjk_runs == null:
		_cjk_runs = RegEx.create_from_string("[\\x{3040}-\\x{30FF}\\x{3400}-\\x{4DBF}\\x{4E00}-\\x{9FFF}\\x{F900}-\\x{FAFF}\\x{AC00}-\\x{D7AF}]+")
		_word_runs = RegEx.create_from_string("[\\p{L}\\p{N}]+")
	var found := PackedStringArray()
	var lowered := text.to_lower()
	for run: RegExMatch in _cjk_runs.search_all(lowered):
		var characters := run.get_string()
		if characters.length() == 1:
			found.append(characters)
		for index in characters.length() - 1:
			found.append(characters.substr(index, 2))
	for run: RegExMatch in _word_runs.search_all(_cjk_runs.sub(lowered, " ", true)):
		var word := run.get_string()
		if word.length() >= 2 and not _COMMON.has(word):
			found.append(word)
	return found

## Up to `count` of `messages` (as `NpcMemory.get_recent_messages()` gives them)
## that share a word with `query`, the best first chosen and then returned in
## the order they were said; none when `query` has no words.
static func recall(messages: Array[Dictionary], query: String, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var query_words := _word_set(query)
	if count <= 0 or messages.is_empty() or query_words.is_empty():
		return result
	var message_words: Array[Dictionary] = []
	var holders := {}
	for message: Dictionary in messages:
		var message_set := _word_set(String(message.get("text", "")))
		message_words.append(message_set)
		for word: String in message_set:
			holders[word] = int(holders.get(word, 0)) + 1
	var scored: Array[Dictionary] = []
	for index in messages.size():
		var score := 0.0
		for word: String in query_words:
			if message_words[index].has(word):
				score += log(1.0 + float(messages.size()) / float(holders[word]))
		if score > 0.0:
			scored.append({"index": index, "score": score * (1.0 + _RECENCY_WEIGHT * float(index + 1) / float(messages.size()))})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var chosen: Array[int] = []
	for entry: Dictionary in scored.slice(0, count):
		chosen.append(int(entry["index"]))
	chosen.sort()
	for index: int in chosen:
		result.append(messages[index].duplicate(true))
	return result

static func _word_set(text: String) -> Dictionary:
	var found := {}
	for word: String in words(text):
		found[word] = true
	return found
