class_name NpcAiSettings
extends ModuleSettings

## What a game sets for NPC chats (`GameDefinition.module_settings`): the
## language model endpoint, if any, how long a line may take and how much an
## NPC says and remembers. Without an endpoint, NPCs chat with the rules the
## game wrote (`NpcRuleProvider`) and nothing goes over the network; with one,
## only once the player allows online services (`GameSettings.online_services`).

## Hosts a plain `http://` endpoint may name: this machine, for development.
const LOCAL_HOSTS: Array[String] = ["localhost", "127.0.0.1", "[::1]"]

## The HTTPS endpoint of a chat model; empty: none. An `http://` one on this
## machine (`LOCAL_HOSTS`) serves development.
@export var endpoint := ""
## The endpoint's chat format (`NpcHttpProvider.FORMATS`).
@export var api_format: StringName = NpcHttpProvider.FORMAT_OPENAI
## The model the endpoint runs, as it names it.
@export var model := ""
## The environment variable that holds the endpoint's key, read only by a
## debug build, for development; empty: the endpoint needs none. A key never
## goes in the game's files, and a released game sends none.
@export var api_key_environment := ""
## How long a line may take before the NPC answers by the rules instead.
@export_range(1.0, 60.0, 0.5) var timeout_seconds := 8.0
## The most characters a line holds; a longer one ends at a sentence before.
@export_range(40, 600) var max_reply_characters := 200
## How many of the latest messages a request carries as the talk so far.
@export_range(0, 24) var recent_messages := 6
## How many older messages that bear on what the player says it carries too
## (`NpcMemoryRecall`).
@export_range(0, 24) var recalled_messages := 4

## The running game's NPC chat settings.
static func current() -> NpcAiSettings:
	return GameDefinition.current().get_settings(NpcAiSettings) as NpcAiSettings

## Whether the game names an endpoint.
func has_endpoint() -> bool:
	return not endpoint.is_empty()

## Whether a request may go to `endpoint`: an `https://` URL, or an `http://`
## one whose host is exactly one of `LOCAL_HOSTS`.
func is_endpoint_safe() -> bool:
	if endpoint.begins_with("https://"):
		return endpoint.length() > "https://".length()
	if not endpoint.begins_with("http://"):
		return false
	var authority := endpoint.trim_prefix("http://").get_slice("/", 0).get_slice("?", 0).get_slice("#", 0)
	if authority.contains("@"):
		return false
	var host := authority.get_slice("]", 0) + "]" if authority.begins_with("[") else authority.get_slice(":", 0)
	return LOCAL_HOSTS.has(host.to_lower())

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if has_endpoint():
		if not is_endpoint_safe():
			problems.append("endpoint '%s' is neither an https:// URL nor an http:// one on this machine" % endpoint)
		if model.is_empty():
			problems.append("names an endpoint but no model")
	if not NpcHttpProvider.FORMATS.has(api_format):
		problems.append("has unknown api format '%s'" % api_format)
	if timeout_seconds <= 0.0:
		problems.append("timeout %s is not above 0 seconds" % timeout_seconds)
	if max_reply_characters < 40:
		problems.append("max reply characters %d is below 40" % max_reply_characters)
	if recent_messages < 0 or recalled_messages < 0:
		problems.append("a message count is below 0")
	return problems
