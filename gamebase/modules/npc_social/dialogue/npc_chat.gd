class_name NpcChat
extends RefCounted

## A conversation made while it runs rather than written in a dialogue file: a
## module that lets NPCs chat (npc_ai) makes one when the player talks to an
## NPC that chats (`ConversationService.chat_maker`), and the balloon shows its
## lines (`DialogueBalloon.start_chat()`), each with the responses that lead on.

## The id of a chat's first line.
const FIRST := ""
## The `next_id` of a response that ends the chat.
const END := "END"

## The line with `id` (`FIRST`, or the `next_id` of the response the player
## chose); null ends the chat. It may await.
func get_line(_id: String) -> DialogueLine:
	return null

## A line `character` says, `text` shown as written (no markup), with
## `responses` to choose from, each {"next_id": String, "text": String} with
## its text as the player reads it.
static func make_line(id: String, character: String, text: String, responses: Array[Dictionary]) -> DialogueLine:
	var line := DialogueLine.new({
		"id": id,
		"type": DMConstants.TYPE_DIALOGUE,
		"next_id": END,
		"character": character,
		"text": text.replace("[", "[lb]"),
	})
	var choices: Array[DialogueResponse] = []
	for response: Dictionary in responses:
		choices.append(DialogueResponse.new({
			"id": "%s:%s" % [id, response["next_id"]],
			"type": DMConstants.TYPE_RESPONSE,
			"next_id": String(response["next_id"]),
			"is_allowed": true,
			"character": "",
			"character_replacements": [] as Array[Dictionary],
			"text": String(response["text"]),
			"text_replacements": [] as Array[Dictionary],
			"tags": PackedStringArray(),
			"static_id": "",
			"condition_as_text": "",
		}))
	line.responses = choices
	return line
