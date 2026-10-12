extends GutTest

## What a provider's answer becomes before an NPC says it (`NpcAiText`).

func test_an_answer_becomes_one_plain_line_without_the_speaker_or_quotes() -> void:
	assert_eq(NpcAiText.clean("  Mira:  \"Fine weather,\n\tisn't it?\"  ", 200, "Mira"), "Fine weather, isn't it?")
	assert_eq(NpcAiText.clean("米拉：「今天天气真好。」", 200, "米拉"), "今天天气真好。")
	assert_eq(NpcAiText.clean("Hi\u0007 there", 200), "Hi there", "control characters go")
	assert_eq(NpcAiText.clean(" \n ", 200), "")

func test_a_long_answer_ends_at_a_sentence_else_a_word_within_the_limit() -> void:
	assert_eq(NpcAiText.clean("The river is high today. Fish bite more after rain, they say.", 40), "The river is high today.")
	assert_eq(NpcAiText.clean("The river is high today and the fish bite well", 30), "The river is high today and…")
	assert_eq(NpcAiText.clean("今天的河水很高。下过雨以后鱼更容易上钩。", 12), "今天的河水很高。")
	var cut := NpcAiText.clean("abcdefghijklmnopqrstuvwxyz", 10)
	assert_eq(cut, "abcdefghi…")
	assert_eq(cut.length(), 10)

func test_a_chat_line_shows_brackets_as_written() -> void:
	var line := NpcChat.make_line("chat:x", "Mira", "Try [b]this[/b]", [{"next_id": NpcChat.END, "text": "Bye"}])
	assert_eq(line.text, "Try [lb]b]this[lb]/b]")
	assert_eq(line.character, "Mira")
	assert_eq(line.responses.size(), 1)
	assert_eq((line.responses[0] as DialogueResponse).next_id, NpcChat.END)
	assert_eq((line.responses[0] as DialogueResponse).text, "Bye")
