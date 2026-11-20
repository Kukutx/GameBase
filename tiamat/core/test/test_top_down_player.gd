extends GutTest

## The player seen from above that a game's player extends (`TopDownPlayer`):
## its reach turns with it, it stands still while the controls are held, and
## a dash carries it.

func test_the_reach_turns_with_the_player() -> void:
	var player := _player()
	watch_signals(player)
	player.face(Vector2(3, 0))
	assert_eq(player.facing, Vector2.RIGHT)
	assert_eq((player.get_node("Hand") as Node2D).position, Vector2(12, 0))
	assert_signal_emitted_with_parameters(player, "facing_changed", [Vector2.RIGHT])
	player.face(Vector2(5, 0))
	assert_signal_emit_count(player, "facing_changed", 1, "walking on the way it faces is no turn")
	player.face(Vector2.ZERO)
	assert_eq(player.facing, Vector2.RIGHT, "no direction keeps the facing")

func test_the_player_stands_still_while_the_controls_are_held() -> void:
	var player := _player()
	player.velocity = Vector2(50, 0)
	InputLock.lock(&"test_top_down_player")
	assert_true(player.is_input_locked())
	player._physics_process(0.016)
	InputLock.unlock(&"test_top_down_player")
	assert_eq(player.velocity, Vector2.ZERO)
	assert_false(player.is_input_locked())

func test_a_dash_carries_the_player_whatever_the_controls_say_until_a_stagger() -> void:
	var player := _player()
	player.global_position = Vector2(-9000, 9000)
	player.dash(Vector2(300, 0), 0.1)
	assert_true(player.is_dashing())
	assert_eq(player.facing, Vector2.RIGHT, "it faces the way it dashes")
	InputLock.lock(&"test_top_down_player")
	player._physics_process(0.05)
	InputLock.unlock(&"test_top_down_player")
	assert_eq(player.velocity, Vector2(300, 0), "held controls do not stop it")
	player._physics_process(0.05)
	assert_false(player.is_dashing(), "it ends once its time is over")
	player.dash(Vector2(0, 300), 1.0)
	player.stagger(0.2)
	player._physics_process(0.016)
	assert_false(player.is_dashing(), "a stagger cuts it short")
	assert_eq(player.velocity, Vector2.ZERO)

func _player() -> TopDownPlayer:
	var player := TopDownPlayer.new()
	player.reach = 12.0
	var hand := Node2D.new()
	hand.name = "Hand"
	player.add_child(hand)
	player.reach_nodes = [NodePath("Hand")]
	add_child_autofree(player)
	return player
