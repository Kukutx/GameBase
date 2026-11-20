extends GutTest

## The core's list of choices (`ChoiceMenu`), which a station, an elevator or
## a way down asks the player to pick from.

var _host: Node

func before_each() -> void:
	_host = Node.new()
	add_child_autofree(_host)

func after_each() -> void:
	InputLock.clear()

func _choices() -> Array[ChoiceMenu.Choice]:
	var choices: Array[ChoiceMenu.Choice] = [
		ChoiceMenu.Choice.new(&"first", "Floor 1"),
		ChoiceMenu.Choice.new(&"second", "Floor 5", "Iron from here on"),
		ChoiceMenu.Choice.new(&"third", "Floor 10", "Locked: reach it first", false),
	]
	return choices

func test_a_node_asks_and_gets_the_choice_the_player_picks() -> void:
	var outcome := {}
	(func() -> void: outcome["picked"] = await ChoiceMenu.ask(_host, _choices(), "Mine Elevator")).call()
	var menu := ChoiceMenu.of(_host)
	assert_not_null(menu, "the menu is added to the node that asks")
	assert_true(menu.is_open())
	assert_true(InputLock.is_locked(), "the world waits for the player")
	assert_eq((menu.get_node("%Title") as Label).text, "Mine Elevator")
	assert_eq(menu.get_buttons().map(func(button: Button) -> String: return button.text), ["Floor 1", "Floor 5", "Floor 10"])
	assert_eq(menu.get_buttons().map(func(button: Button) -> bool: return button.disabled), [false, false, true])
	assert_eq(menu.get_note(&"first"), "", "a choice without a note has no line")
	assert_eq(menu.get_note(&"second"), "Iron from here on")
	assert_true(menu.choose(&"second"))
	assert_eq(outcome.get("picked"), &"second")
	assert_false(menu.is_open())
	assert_false(InputLock.is_locked())

func test_closing_the_list_picks_nothing_and_a_locked_choice_cannot_be_picked() -> void:
	var outcome := {}
	(func() -> void: outcome["picked"] = await ChoiceMenu.ask(_host, _choices())).call()
	var menu := ChoiceMenu.of(_host)
	assert_eq((menu.get_node("%Title") as Label).text, "Choose", "a list without a title says Choose")
	assert_false(menu.choose(&"third"), "a locked choice")
	assert_false(menu.choose(&"fourth"), "a choice the list does not hold")
	assert_true(menu.is_open())
	menu.close()
	assert_eq(outcome.get("picked"), &"")

func test_the_focus_starts_on_the_choice_asked_for_or_the_first_open_one() -> void:
	(func() -> void: await ChoiceMenu.ask(_host, _choices(), "", &"second")).call()
	var menu := ChoiceMenu.of(_host)
	assert_true(menu.get_button(&"second").has_focus())
	menu.close()
	(func() -> void: await ChoiceMenu.ask(_host, _choices(), "", &"third")).call()
	assert_true(menu.get_button(&"first").has_focus(), "not on a locked one")
	menu.close()
	assert_eq(_host.get_children().size(), 1, "asking again reuses the menu")

func test_a_choice_listed_twice_shows_once() -> void:
	var choices := _choices()
	choices.append(ChoiceMenu.Choice.new(&"first", "Floor 1 again"))
	(func() -> void: await ChoiceMenu.ask(_host, choices)).call()
	var menu := ChoiceMenu.of(_host)
	assert_eq(menu.get_buttons().size(), 3)
	assert_eq(menu.get_button(&"first").text, "Floor 1")
	menu.close()
