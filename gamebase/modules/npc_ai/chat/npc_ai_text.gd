class_name NpcAiText
extends RefCounted

## Makes what a provider answers into a line an NPC says: plain text on one
## line, without the speaker's name in front or quotes around it, cut at the
## end of a sentence to fit. `DialogueChat.make_line()` shows it as written, not as
## markup.

# Where a sentence ends, in the languages a game shows.
const _SENTENCE_ENDS := ".!?。！？…"
const _QUOTES := [["\"", "\""], ["“", "”"], ["「", "」"], ["'", "'"]]

static var _control: RegEx
static var _spaces: RegEx

## `text` as one clean line of at most `max_characters` characters; empty when
## nothing is left of it.
static func clean(text: String, max_characters: int, speaker := "") -> String:
	if _control == null:
		_control = RegEx.create_from_string("[\\x{0}-\\x{1F}\\x{7F}]")
		_spaces = RegEx.create_from_string("\\s+")
	var line := _spaces.sub(_control.sub(text, " ", true), " ", true).strip_edges()
	if not speaker.is_empty():
		for separator: String in [":", "："]:
			if line.begins_with(speaker + separator):
				line = line.substr(speaker.length() + 1).strip_edges()
	for pair: Array in _QUOTES:
		if line.length() >= 2 and line.begins_with(pair[0]) and line.ends_with(pair[1]):
			line = line.substr(1, line.length() - 2).strip_edges()
	if line.length() > max_characters:
		line = _shorten(line, max_characters)
	return line

## `text` up to the end of its last whole sentence; empty when it has none:
## what is worth showing of a line cut off mid-sentence.
static func whole_sentences(text: String) -> String:
	for index in range(text.length() - 1, -1, -1):
		if _SENTENCE_ENDS.contains(text[index]):
			return text.substr(0, index + 1)
	return ""

# The first `max_characters` of `line`, ended at the last sentence end in their
# second half, else at the last space there with an ellipsis, else cut.
static func _shorten(line: String, max_characters: int) -> String:
	var cut := line.substr(0, max_characters)
	var half := floori(max_characters / 2.0)
	for index in range(cut.length() - 1, half - 1, -1):
		if _SENTENCE_ENDS.contains(cut[index]):
			return cut.substr(0, index + 1)
	var space := cut.rfind(" ")
	if space >= half:
		return cut.substr(0, space).strip_edges() + "…"
	return cut.substr(0, max_characters - 1) + "…"
