extends GutTest

## Locks on the player's controls and the world's pause by reason
## (`InputLockService`).

func after_each() -> void:
	InputLock.clear()

func test_locks_add_up_and_the_world_stays_paused_while_one_pauses() -> void:
	InputLock.lock(&"fixture_menu", true)
	InputLock.lock(&"fixture_minigame", true)
	InputLock.unlock(&"fixture_menu")
	assert_true(get_tree().paused, "the minigame still pauses the world")
	assert_true(InputLock.is_locked())
	InputLock.unlock(&"fixture_minigame")
	assert_false(get_tree().paused)
	assert_false(InputLock.is_locked())

func test_a_lock_that_does_not_pause_only_holds_the_controls() -> void:
	InputLock.lock(&"fixture_dialogue")
	assert_true(InputLock.is_locked())
	assert_false(get_tree().paused)
	assert_eq(InputLock.get_reasons(), [&"fixture_dialogue"])

func test_a_lock_is_given_back_when_its_owner_leaves_the_tree() -> void:
	var menu := Node.new()
	add_child(menu)
	InputLock.lock(&"fixture_menu", true, menu)
	menu.free()
	assert_false(InputLock.is_held(&"fixture_menu"))
	assert_false(get_tree().paused)

func test_an_owner_that_gave_its_lock_back_no_longer_releases_it() -> void:
	var first := Node.new()
	var second := Node.new()
	add_child(first)
	add_child_autofree(second)
	InputLock.lock(&"fixture_menu", false, first)
	InputLock.unlock(&"fixture_menu")
	InputLock.lock(&"fixture_menu", false, second)
	first.free()
	assert_true(InputLock.is_held(&"fixture_menu"), "the second owner holds it now")

func test_one_owner_s_locks_are_each_given_back() -> void:
	var minigame := Node.new()
	add_child(minigame)
	InputLock.lock(&"fixture_minigame", true, minigame)
	InputLock.lock(&"fixture_dialogue", false, minigame)
	InputLock.unlock(&"fixture_dialogue")
	assert_true(InputLock.is_held(&"fixture_minigame"))
	InputLock.lock(&"fixture_dialogue", false, minigame)
	minigame.free()
	assert_eq(InputLock.get_reasons(), [], "leaving the tree gives back both")
	assert_false(get_tree().paused)

func test_clearing_gives_back_every_lock() -> void:
	InputLock.lock(&"fixture_menu", true)
	InputLock.lock(&"fixture_dialogue")
	watch_signals(InputLock)
	InputLock.clear()
	assert_false(InputLock.is_locked())
	assert_false(get_tree().paused)
	assert_signal_emitted(InputLock, "changed")
