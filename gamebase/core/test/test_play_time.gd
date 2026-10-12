extends GutTest

## The time played (`GameSession.get_play_seconds()`): it runs while play does,
## stops while the session changes or the world is paused, and a save keeps it.

var _play_seconds := 0.0
var _playing := false

func before_each() -> void:
	_play_seconds = float(GameSession.get("_play_seconds"))
	_playing = bool(GameSession.get("_playing"))

func after_each() -> void:
	GameSession.set("_play_seconds", _play_seconds)
	GameSession.set("_playing", _playing)
	GameSession.set("_starting_new_game", false)

func test_the_time_runs_while_play_does_and_not_while_the_session_changes() -> void:
	GameSession.set("_play_seconds", 59.5)
	GameSession.set("_playing", false)
	GameSession._process(10.0)
	assert_eq(GameSession.get_play_seconds(), 59, "nothing runs before play starts")
	GameSession.set("_playing", true)
	GameSession._process(0.75)
	assert_eq(GameSession.get_play_seconds(), 60)
	GameSession.set("_starting_new_game", true)
	GameSession._process(10.0)
	assert_eq(GameSession.get_play_seconds(), 60, "a new game being set up adds no time")

func test_the_time_stops_with_the_world() -> void:
	assert_true(GameSession.can_process())
	InputLock.lock(&"test_play_time", true)
	assert_false(GameSession.can_process(), "a paused world adds no time")
	InputLock.unlock(&"test_play_time")
	assert_true(GameSession.can_process())

func test_a_save_keeps_the_time_and_a_new_game_starts_from_none() -> void:
	assert_true(SaveManager.get_section_ids().has(String(GameSessionService.SAVE_SECTION)))
	GameSession.set("_play_seconds", 4000.9)
	var section: Dictionary = GameSession.call("_to_save_data")
	assert_eq(section, {"play_seconds": 4000})
	GameSession.set("_play_seconds", 0.0)
	GameSession.call("_load_save_data", section, {String(GameSessionService.SAVE_SECTION): section})
	assert_eq(GameSession.get_play_seconds(), 4000)
	var steps: Array = GameSession.get("_new_game_steps")
	var reset := steps.filter(func(step: Dictionary) -> bool: return step["id"] == GameSessionService.SAVE_SECTION)
	assert_eq(reset.size(), 1, "a new game resets the time")
	(reset[0]["step"] as Callable).call()
	assert_eq(GameSession.get_play_seconds(), 0)
