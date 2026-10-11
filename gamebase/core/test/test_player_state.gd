extends GutTest

func test_energy_and_money_round_trip() -> void:
	var state := GlobalPlayerState.new()
	add_child_autofree(state)
	state.max_energy = 120
	state.energy = 120
	state.money = 300

	assert_true(state.consume_energy(25))
	assert_eq(state.energy, 95)
	assert_true(state.spend_money(80))
	assert_eq(state.money, 220)

	var restored := GlobalPlayerState.new()
	add_child_autofree(restored)
	restored.load_save_data(state.to_save_data())
	assert_eq(restored.max_energy, 120)
	assert_eq(restored.energy, 95)
	assert_eq(restored.money, 220)

func test_energy_cannot_go_below_zero() -> void:
	var state := GlobalPlayerState.new()
	add_child_autofree(state)
	state.energy = 3
	assert_false(state.consume_energy(4))
	assert_eq(state.energy, 3)

func test_health_and_money_loss_round_trip() -> void:
	var state := GlobalPlayerState.new()
	add_child_autofree(state)
	state.max_health = 140
	state.health = 140
	state.money = 250
	assert_true(state.take_damage(45))
	assert_eq(state.health, 95)
	state.heal(20)
	assert_eq(state.health, 115)
	assert_eq(state.lose_money(30), 30)
	assert_eq(state.money, 220)

	var restored := GlobalPlayerState.new()
	add_child_autofree(restored)
	restored.load_save_data(state.to_save_data())
	assert_eq(restored.max_health, 140)
	assert_eq(restored.health, 115)
	assert_eq(restored.money, 220)
