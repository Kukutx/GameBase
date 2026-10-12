extends GutTest

## The player's line of short messages (`StatusLine`).

func test_messages_sent_together_are_each_shown_in_turn() -> void:
	var line := _line()
	GameEvents.toast("Fixture harvest")
	GameEvents.toast("Fixture achievement")
	assert_eq(line.text, "Fixture harvest")
	assert_eq(line.get_waiting(), PackedStringArray(["Fixture achievement"]))
	line._process(1.0)
	assert_eq(line.text, "Fixture harvest", "a message stays its time")
	line._process(1.0)
	assert_eq(line.text, "Fixture achievement")
	line._process(2.0)
	assert_eq(line.text, "")

func test_a_repeated_message_stays_longer_instead_of_waiting() -> void:
	var line := _line()
	line.show_message("Not enough energy")
	line._process(1.5)
	line.show_message("Not enough energy")
	assert_eq(line.get_waiting(), PackedStringArray())
	line._process(1.5)
	assert_eq(line.text, "Not enough energy", "its time starts again")
	line.show_message("Saved")
	line.show_message("Saved")
	assert_eq(line.get_waiting(), PackedStringArray(["Saved"]), "a message waits once")

func test_the_oldest_waiting_message_gives_way() -> void:
	var line := _line()
	for message: String in ["a", "b", "c", "d", "e"]:
		line.show_message(message)
	assert_eq(line.text, "a")
	assert_eq(line.get_waiting(), PackedStringArray(["c", "d", "e"]))

func test_a_line_can_leave_toasts_to_another() -> void:
	var line := StatusLine.new()
	line.shows_toasts = false
	add_child_autofree(line)
	GameEvents.toast("Saved")
	assert_eq(line.text, "")

func _line() -> StatusLine:
	var line := StatusLine.new()
	line.seconds_per_message = 2.0
	add_child_autofree(line)
	line.set_process(false)
	return line
