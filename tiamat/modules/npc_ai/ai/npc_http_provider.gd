class_name NpcHttpProvider
extends NpcAiProvider

## A language model behind an HTTPS endpoint the game names (`NpcAiSettings`):
## one POST per line, in the chat format of the endpoint (`FORMAT_OPENAI`, a
## chat completions endpoint, or `FORMAT_ANTHROPIC`, a messages endpoint), with
## the instructions and messages of `NpcAiPrompt`. Any failure (no answer in
## time, a status other than 2xx, a body it cannot read) gives an empty line,
## and `NpcAi` falls back to the rules.
##
## The key, if the endpoint needs one, comes from the environment variable the
## settings name, and only in a debug build, never from the game's files; a
## released game points at an endpoint of its own that holds the key. It never
## follows a redirect, which could take the key elsewhere. An answer the
## endpoint cut off at its token limit keeps its whole sentences.

const FORMAT_OPENAI := &"openai"
const FORMAT_ANTHROPIC := &"anthropic"
const FORMATS: Array[StringName] = [FORMAT_OPENAI, FORMAT_ANTHROPIC]
const ANTHROPIC_VERSION := "2023-06-01"
## Room for a reply of `max_reply_characters`, in tokens: a Chinese character
## can take more than one.
const TOKENS_PER_CHARACTER := 1.5

var settings: NpcAiSettings
## Sends one request: Callable(url: String, headers: PackedStringArray, body:
## String) -> {"code": int, "body": String}, code 0 when nothing came back. It
## may await. By default an `HTTPRequest` under `host`; a test sets its own.
var send: Callable
## The node the default `send` puts its requests under, which runs while the
## world is paused for the chat.
var host: Node

func _init(provider_settings: NpcAiSettings, request_host: Node = null) -> void:
	settings = provider_settings
	host = request_host
	send = _post

func get_source() -> StringName:
	return &"http"

func reply(request: NpcAiRequest) -> String:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var key := OS.get_environment(settings.api_key_environment) if OS.is_debug_build() and not settings.api_key_environment.is_empty() else ""
	var body := {
		"model": settings.model,
		"max_tokens": maxi(ceili(settings.max_reply_characters * TOKENS_PER_CHARACTER), 16),
	}
	if settings.api_format == FORMAT_ANTHROPIC:
		headers.append("anthropic-version: " + ANTHROPIC_VERSION)
		if not key.is_empty():
			headers.append("x-api-key: " + key)
		body["system"] = NpcAiPrompt.instructions(request)
		body["messages"] = NpcAiPrompt.messages(request)
	else:
		if not key.is_empty():
			headers.append("Authorization: Bearer " + key)
		var turns: Array[Dictionary] = [{"role": "system", "content": NpcAiPrompt.instructions(request)}]
		turns.append_array(NpcAiPrompt.messages(request))
		body["messages"] = turns
	var response: Dictionary = await send.call(settings.endpoint, headers, JSON.stringify(body))
	var code := int(response.get("code", 0))
	if code < 200 or code >= 300:
		return ""
	return read_reply(String(response.get("body", "")), settings.api_format)

## The text of a reply `body` in `format`, its whole sentences only when the
## endpoint cut it off; empty when it holds none.
static func read_reply(body: String, format: StringName) -> String:
	# A JSON object, not JSON.parse_string(), which logs an error for a body
	# that is not JSON, such as a proxy's error page.
	var json := JSON.new()
	if json.parse(body) != OK or not json.data is Dictionary:
		return ""
	var data: Dictionary = json.data
	if format == FORMAT_ANTHROPIC:
		var parts := PackedStringArray()
		var blocks: Variant = data.get("content", [])
		if blocks is Array:
			for block: Variant in blocks:
				if block is Dictionary and (block as Dictionary).get("type", "") == "text":
					parts.append(String((block as Dictionary).get("text", "")))
		var text := "".join(parts)
		return NpcAiText.whole_sentences(text) if data.get("stop_reason", "") == "max_tokens" else text
	var choices: Variant = data.get("choices", [])
	if not choices is Array or (choices as Array).is_empty() or not (choices as Array)[0] is Dictionary:
		return ""
	var choice: Dictionary = (choices as Array)[0]
	var message: Variant = choice.get("message", {})
	var content: Variant = (message as Dictionary).get("content", "") if message is Dictionary else ""
	if not content is String:
		return ""
	return NpcAiText.whole_sentences(content) if choice.get("finish_reason", "") == "length" else content

func _post(url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if host == null or not host.is_inside_tree():
		return {"code": 0, "body": ""}
	var http := HTTPRequest.new()
	http.timeout = settings.timeout_seconds
	http.max_redirects = 0
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(http)
	if http.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		return {"code": 0, "body": ""}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": ""}
	return {"code": int(result[1]), "body": (result[3] as PackedByteArray).get_string_from_utf8()}
