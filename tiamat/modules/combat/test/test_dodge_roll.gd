extends GutTest

## The player's dodge (`DodgeRoll`): a roll the way the player faces, safe
## from hits, then a moment before the next.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

var _vitals_snapshot: Dictionary

func before_each() -> void:
	_vitals_snapshot = Vitals.to_save_data()
	ContentFixture.use(self, [ContentFixture.vital(&"fixture_hp"), ContentFixture.vital(&"fixture_stamina")])
	var settings := CombatSettings.new()
	settings.health_vital_id = &"fixture_hp"
	ContentFixture.use_settings(self, [settings])
	Vitals.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	Vitals.load_save_data(_vitals_snapshot)

func test_a_roll_carries_the_player_the_way_it_faces_safe_from_hits() -> void:
	var player := _add_player()
	var dodge := player.get_node("DodgeRoll") as DodgeRoll
	var hurtbox := Hurtbox.of(player)
	player.face(Vector2.RIGHT)
	watch_signals(CombatEvents)
	assert_true(dodge.roll())
	assert_signal_emit_count(CombatEvents, "player_dodged", 1)
	assert_true(player.is_dashing())
	assert_lt(player.modulate.a, 1.0, "the player shows faded while it rolls")
	assert_false(hurtbox.receive(Damage.new(5, FactionData.MONSTERS)), "no hit hurts it on the way")
	assert_true(Vitals.is_full(&"fixture_hp"))
	assert_false(dodge.roll(), "one roll at a time")
	assert_true(await wait_until(func() -> bool: return not player.is_dashing(), 1.0))
	assert_almost_eq(player.global_position.x, -9000.0 + dodge.distance, 6.0, "its distance the way it faces")
	assert_almost_eq(player.global_position.y, 9000.0, 0.5)
	assert_true(dodge.is_cooling_down(), "the next waits a moment")
	assert_false(dodge.roll())
	assert_true(await wait_until(func() -> bool: return not dodge.is_cooling_down(), 2.0))
	assert_eq(player.modulate.a, 1.0, "and shows whole again")
	assert_true(dodge.roll(), "then rolls again")

func test_no_roll_while_the_controls_are_held_or_a_hit_staggers_the_player() -> void:
	var player := _add_player()
	var dodge := player.get_node("DodgeRoll") as DodgeRoll
	InputLock.lock(&"test_dodge_roll")
	assert_false(dodge.roll(), "the controls are held")
	InputLock.unlock(&"test_dodge_roll")
	player.stagger(0.2)
	assert_false(dodge.roll(), "the player reels from a hit")
	assert_false(player.is_dashing())

func test_a_roll_costs_its_share_of_the_attack_vital() -> void:
	var settings := CombatSettings.new()
	settings.health_vital_id = &"fixture_hp"
	settings.attack_vital_id = &"fixture_stamina"
	ContentFixture.use_settings(self, [settings])
	var player := _add_player()
	var dodge := player.get_node("DodgeRoll") as DodgeRoll
	dodge.cost = 60
	dodge.cooldown_seconds = 0.0
	assert_true(dodge.roll())
	assert_eq(Vitals.get_value(&"fixture_stamina"), 40)
	assert_true(await wait_until(func() -> bool: return not dodge.is_cooling_down(), 1.0))
	assert_false(dodge.roll(), "not without enough left")
	assert_false(player.is_dashing())

func _add_player() -> TopDownPlayer:
	var player := TopDownPlayer.new()
	var hurtbox := PlayerHurtbox.new()
	player.add_child(hurtbox)
	var dodge := DodgeRoll.new()
	dodge.name = "DodgeRoll"
	player.add_child(dodge)
	player.global_position = Vector2(-9000, 9000)
	add_child_autofree(player)
	return player
