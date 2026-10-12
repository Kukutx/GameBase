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

func test_a_line_that_shows_hints_keeps_each_one_longer() -> void:
	var line := _line()
	GameEvents.hint_requested.emit("Fixture hint")
	assert_eq(line.text, "", "a line shows no hints unless asked to")
	var hints := StatusLine.new()
	hints.shows_hints = true
	hints.seconds_per_hint = 5.0
	add_child_autofree(hints)
	hints.set_process(false)
	GameEvents.hint_requested.emit("Fixture hint")
	GameEvents.toast("Saved")
	assert_eq(hints.text, "Fixture hint")
	hints._process(4.0)
	assert_eq(hints.text, "Fixture hint", "a hint stays its own time")
	hints._process(1.0)
	assert_eq(hints.text, "Saved")

func test_a_line_says_how_a_save_went_unless_another_line_does() -> void:
	var line := _line()
	SaveManager.save_completed.emit(true, "Fixture saved")
	assert_eq(line.text, "Fixture saved")
	var quiet := StatusLine.new()
	quiet.shows_saves = false
	add_child_autofree(quiet)
	SaveManager.save_completed.emit(true, "Fixture saved again")
	assert_eq(quiet.text, "")

func _line() -> StatusLine:
	var line := StatusLine.new()
	line.seconds_per_message = 2.0
	add_child_autofree(line)
	line.set_process(false)
	return line
