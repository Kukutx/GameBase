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

func test_hotbar_round_trip() -> void:
	var hotbar := HotbarService.new()
	add_child_autofree(hotbar)
	hotbar.select_slot(2)
	var restored := HotbarService.new()
	add_child_autofree(restored)
	restored.load_save_data(hotbar.to_save_data())
	assert_eq(restored.selected_slot, 2)
	assert_eq(restored.get_selected_item_id(), &"pickaxe")

func test_removed_legacy_hotbar_item_is_cleared_without_touching_inventory_payload() -> void:
	var hotbar := HotbarService.new()
	add_child_autofree(hotbar)
	hotbar.load_save_data({
		"selected_slot": 0,
		"slots": ["removed_item", "hoe", "", "", "", "", "", "", ""],
	})
	assert_eq(hotbar.slots[0], &"")
	assert_eq(hotbar.slots[1], &"hoe")
	assert_eq(hotbar.get_selected_item_id(), &"")
	assert_null(hotbar.get_selected_item())

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
