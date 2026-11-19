extends GutTest

## The player seen from above that a game's player extends (`TopDownPlayer`):
## its reach turns with it, and it stands still while the controls are held.

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

func _player() -> TopDownPlayer:
	var player := TopDownPlayer.new()
	player.reach = 12.0
	var hand := Node2D.new()
	hand.name = "Hand"
	player.add_child(hand)
	player.reach_nodes = [NodePath("Hand")]
	add_child_autofree(player)
	return player
