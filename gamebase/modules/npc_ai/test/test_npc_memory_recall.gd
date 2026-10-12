extends GutTest

## Which remembered messages an NPC recalls for what the player says
## (`NpcMemoryRecall`), and how text splits into words.

func test_words_are_lowercased_runs_and_neighbouring_chinese_characters() -> void:
	assert_eq(NpcMemoryRecall.words("The Spring Festival, 2 days!"), PackedStringArray(["spring", "festival", "days"]),
		"common words and single characters drop out")
	assert_eq(NpcMemoryRecall.words("春季节日"), PackedStringArray(["春季", "季节", "节日"]))
	assert_eq(NpcMemoryRecall.words("鱼 fish"), PackedStringArray(["鱼", "fish"]), "a Chinese character alone is a word")

func test_recall_picks_the_messages_that_share_the_rarest_words_and_keeps_their_order() -> void:
	var messages := _messages([
		"I caught a big fish in the river.",
		"The weather is lovely today.",
		"Do you like the river at night?",
		"The weather was lovely yesterday.",
		"Fish taste best grilled.",
	])
	var recalled := NpcMemoryRecall.recall(messages, "Where do you fish?", 2)
	assert_eq(_texts(recalled), PackedStringArray(["I caught a big fish in the river.", "Fish taste best grilled."]))

func test_among_equal_matches_the_latest_is_recalled() -> void:
	var messages := _messages(["The festival starts soon.", "Nothing new.", "The festival was fun."])
	assert_eq(_texts(NpcMemoryRecall.recall(messages, "festival", 1)), PackedStringArray(["The festival was fun."]))

func test_nothing_is_recalled_without_a_shared_word_or_room() -> void:
	var messages := _messages(["Hello there.", "春季节日快到了。"])
	assert_eq(NpcMemoryRecall.recall(messages, "boats", 3).size(), 0)
	assert_eq(NpcMemoryRecall.recall(messages, "the", 3).size(), 0, "a query of common words only matches nothing")
	assert_eq(NpcMemoryRecall.recall(messages, "节日", 0).size(), 0)
	assert_eq(_texts(NpcMemoryRecall.recall(messages, "节日什么时候？", 3)), PackedStringArray(["春季节日快到了。"]))

func _messages(texts: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in texts.size():
		result.append({"role": "player" if index % 2 == 0 else "npc", "text": texts[index], "day": index + 1})
	return result

func _texts(messages: Array[Dictionary]) -> PackedStringArray:
	var result := PackedStringArray()
	for message: Dictionary in messages:
		result.append(String(message["text"]))
	return result
