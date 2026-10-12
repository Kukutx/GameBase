class_name NpcAiService
extends Node

## The lines NPCs chat with (`NpcAiChat`). It builds each request from what the
## NPC knows (`NpcContext`) and remembers (`NpcMemory`: the latest messages and
## the older ones that bear on what the player says, `NpcMemoryRecall`), and
## answers requests one at a time in the order they come: from the game's
## language model (`NpcAiSettings.endpoint`) once the player allows online
## services, else, or when the model answers nothing or takes longer than the
## settings allow, from the rules the game wrote (`NpcRuleProvider`). Every
## request gets an answer, so a chat works offline and never waits for long.
## It saves nothing.

## A request was answered, from `source` (`SOURCE_RULES` or a provider's).
signal answered(npc_id: StringName, source: StringName)

## The source of the rules' answers.
const SOURCE_RULES := &"rules"

## What answers before the rules in place of the game's endpoint: a test's
## stand-in. Null: the endpoint, if the game names one.
var provider: NpcAiProvider
var rules := NpcRuleProvider.new()
var _queue: Array[NpcAiRequest] = []
var _working := false
var _http: NpcHttpProvider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Asks for `npc_id`'s line: its greeting, or its answer to `topic`, which the
## player `actor` brings up. Await the request's `wait()` for the line.
func ask(npc_id: StringName, topic: ChatTopicData = null, actor: Node = null) -> NpcAiRequest:
	var request := make_request(npc_id, topic, actor)
	submit(request)
	return request

## The request `ask()` would make, not yet submitted.
func make_request(npc_id: StringName, topic: ChatTopicData = null, actor: Node = null) -> NpcAiRequest:
	var settings := NpcAiSettings.current()
	var request := NpcAiRequest.new()
	request.npc_id = npc_id
	request.topic = topic
	request.player_text = tr(topic.title) if topic != null else ""
	request.context = NpcContext.build_context(npc_id, actor)
	request.locale = TranslationServer.get_locale()
	var memory := NpcMemory.get_recent_messages(npc_id)
	var older := maxi(memory.size() - settings.recent_messages, 0)
	request.recent = memory.slice(older)
	request.recalled = NpcMemoryRecall.recall(memory.slice(0, older), request.player_text, settings.recalled_messages)
	return request

## Queues `request` to be answered after those before it.
func submit(request: NpcAiRequest) -> void:
	_queue.append(request)
	if not _working:
		_work()

## Drops the requests not started on: a load, a new game or the title takes
## the player out of their chat.
func cancel_all() -> void:
	for request: NpcAiRequest in _queue:
		request.cancel()
	_queue.clear()

## Whether a request is being answered or waits.
func is_busy() -> bool:
	return _working

## What answers before the rules now: `provider`, else the game's endpoint once
## the player allows online services; null when the rules answer.
func get_online_provider() -> NpcAiProvider:
	if provider != null:
		return provider
	var settings := NpcAiSettings.current()
	if not settings.has_endpoint() or not settings.is_endpoint_safe() or not GameSettings.online_services:
		return null
	if _http == null or _http.settings != settings:
		_http = NpcHttpProvider.new(settings, self)
	return _http

func _work() -> void:
	_working = true
	while not _queue.is_empty():
		var request: NpcAiRequest = _queue.pop_front()
		if request.is_cancelled() or request.is_done():
			continue
		_answer(request)
		if not request.is_done() and not request.is_cancelled():
			await request.settled
		if request.is_done():
			answered.emit(request.npc_id, request.source)
	_working = false

func _answer(request: NpcAiRequest) -> void:
	var online := get_online_provider()
	if online == null:
		_answer_by_rules(request)
		return
	get_tree().create_timer(NpcAiSettings.current().timeout_seconds, true, false, true).timeout.connect(_answer_by_rules.bind(request))
	_answer_online(online, request)

func _answer_online(online: NpcAiProvider, request: NpcAiRequest) -> void:
	var line := _clean(await online.reply(request), request)
	if line.is_empty():
		_answer_by_rules(request)
	else:
		request.finish(line, online.get_source())

func _answer_by_rules(request: NpcAiRequest) -> void:
	if not request.is_done() and not request.is_cancelled():
		request.finish(_clean(rules.reply(request), request), SOURCE_RULES)

func _clean(line: String, request: NpcAiRequest) -> String:
	var speaker := tr(String((request.context.get("npc", {}) as Dictionary).get("name", "")))
	return NpcAiText.clean(line, NpcAiSettings.current().max_reply_characters, speaker)
