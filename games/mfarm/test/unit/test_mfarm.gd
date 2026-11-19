extends GutTest

## MFarm's own rules: the bags and money, the land and its crops, the
## townsfolk's day and the clock's face.

var _state: Dictionary

func before_each() -> void:
	_state = WorldState.to_save_data()
	WorldState.clear()

func after_each() -> void:
	WorldState.load_save_data(_state)

func test_a_new_game_starts_with_an_empty_bag_and_100_coins() -> void:
	assert_eq(Bags.money, MFarmBagService.START_MONEY)
	assert_eq(Bags.get_slots(Bags.PLAYER).size(), 26)
	assert_eq(Bags.count(Bags.PLAYER, &"hoe"), 0)

func test_buying_takes_money_and_stock_and_a_full_bag_buys_nothing() -> void:
	Bags.ensure_bag(&"shop:test", &"koyo_shop")
	assert_true(Bags.buy(&"shop:test", 3, 2), "two grape seeds for 20 coins")
	assert_eq(Bags.money, 80)
	assert_eq(Bags.count(Bags.PLAYER, &"grape_seed"), 2)
	assert_eq(int(Bags.get_slot(&"shop:test", 3).amount), 3)
	assert_false(Bags.buy(&"shop:test", 0, 1), "a potato seed costs more than 80 coins")
	for index: int in Bags.get_slots(Bags.PLAYER).size():
		Bags.add_item(Bags.PLAYER, &"stone", MFarmItemData.MAX_STACK)
	var money := Bags.money
	assert_false(Bags.buy(&"shop:test", 2, 1), "the old game charged for what a full bag could not take")
	assert_eq(Bags.money, money)

func test_selling_pays_the_sell_price() -> void:
	Bags.add_item(Bags.PLAYER, &"potato", 2)
	var index := _slot_of(&"potato")
	assert_true(Bags.sell(index, 2))
	assert_eq(Bags.money, MFarmBagService.START_MONEY + 2 * MFarmItemData.find(&"potato").get_sell_price())
	assert_false(Bags.sell(_slot_of(&"hoe"), 1), "nothing to sell")

func test_items_move_merge_and_swap_between_bags() -> void:
	Bags.ensure_bag(&"box:test", &"tool_box")
	assert_true(Bags.move_slot(&"box:test", 1, Bags.PLAYER, 0))
	assert_eq(Bags.get_slot(Bags.PLAYER, 0).item, &"hoe")
	assert_eq(Bags.get_slot(&"box:test", 1).item, &"")
	Bags.add_item(Bags.PLAYER, &"stone", 3)
	Bags.add_item(&"box:test", &"stone", 4)
	assert_true(Bags.move_slot(&"box:test", _slot_in(&"box:test", &"stone"), Bags.PLAYER, _slot_of(&"stone")))
	assert_eq(Bags.count(Bags.PLAYER, &"stone"), 7)

func test_boxes_keep_their_contents_through_a_save() -> void:
	Bags.ensure_bag(&"box:test", &"empty_box")
	Bags.add_item(&"box:test", &"stone", 5)
	var saved := WorldState.to_save_data()
	WorldState.clear()
	assert_false(Bags.has_bag(&"box:test"))
	WorldState.load_save_data(saved)
	assert_eq(Bags.count(&"box:test", &"stone"), 5)

func test_a_dug_and_planted_cell_grows_to_a_harvest() -> void:
	var cell := Vector2i(16, 2)
	assert_true(Farmland.dig(&"field", cell))
	assert_true(Farmland.water(&"field", cell))
	assert_true(Farmland.plant(&"field", cell, &"potato_seed"))
	assert_false(Farmland.can_harvest(&"field", cell, &"basket"), "a seed is not ripe")
	for _day: int in MFarmCropData.find(&"potato_seed").get_total_days():
		Farmland.call("_on_day_changed", 0)
	assert_false(Farmland.is_watered(&"field", cell), "soil dries overnight")
	assert_true(Farmland.can_harvest(&"field", cell, &"basket"))
	assert_false(Farmland.can_harvest(&"field", cell, &"axe"), "only the basket picks potatoes")
	var result := Farmland.work_crop(&"field", cell, &"basket")
	assert_true(bool(result.get("harvested", false)))
	assert_eq(Farmland.get_tile(&"field", cell).seed, &"")

func test_grapes_regrow_after_picking() -> void:
	var cell := Vector2i(17, 2)
	Farmland.dig(&"field", cell)
	Farmland.plant(&"field", cell, &"grape_seed")
	var crop := MFarmCropData.find(&"grape_seed")
	for _day: int in crop.get_total_days():
		Farmland.call("_on_day_changed", 0)
	Farmland.work_crop(&"field", cell, &"basket")
	assert_eq(Farmland.get_tile(&"field", cell).seed, &"grape_seed", "the vine stays")
	assert_false(Farmland.is_ripe(&"field", cell))
	for _day: int in crop.days_to_regrow:
		Farmland.call("_on_day_changed", 0)
	assert_true(Farmland.is_ripe(&"field", cell))

func test_dug_soil_left_empty_fills_in() -> void:
	var cell := Vector2i(18, 2)
	Farmland.dig(&"field", cell)
	for _day: int in MFarmFarmService.DAYS_SOIL_STAYS_DUG + 1:
		Farmland.call("_on_day_changed", 0)
	assert_false(Farmland.is_dug(&"field", cell))

func test_the_grid_redraws_only_the_soil_a_change_touches() -> void:
	var location := MFarmLocation.new()
	location.location_id = &"field"
	var grid := MFarmFarmGrid.new()
	location.add_child(grid)
	add_child_autofree(location)
	var soil := grid.get_node("Soil")
	Farmland.dig(&"field", Vector2i(16, 2))
	assert_eq(soil.get_child_count(), 1)
	var first := soil.get_child(0) as Sprite2D
	var alone := first.texture
	Farmland.dig(&"field", Vector2i(17, 2))
	assert_eq(soil.get_child_count(), 2)
	assert_true(is_instance_valid(first) and first.get_parent() == soil, "the dug cell keeps its sprite")
	assert_ne(first.texture, alone, "and turns to the tile that joins its neighbour")
	for _day: int in MFarmFarmService.DAYS_SOIL_STAYS_DUG + 1:
		Farmland.call("_on_day_changed", 0)
	await wait_physics_frames(1)
	assert_eq(soil.get_child_count(), 0, "soil that filled in goes")

func test_only_the_map_s_diggable_cells_dig() -> void:
	assert_true(Farmland.can_dig(&"field", Vector2i(12, 1)))
	assert_false(Farmland.can_dig(&"field", Vector2i(0, 0)))
	assert_false(Farmland.can_dig(&"home", Vector2i(12, 1)))

func test_the_mayor_s_day_follows_his_schedule() -> void:
	var mayor := MFarmNpcData.find(&"mayor")
	assert_eq(mayor.get_entry_at(9 * 60).cell, Vector2i(-8, 4), "thinking in the field from eight")
	assert_true(mayor.get_entry_at(9 * 60).interactable)
	assert_false(mayor.get_entry_at(11 * 60).interactable, "stretching from ten, too busy to talk")
	assert_eq(mayor.get_entry_at(7 * 60), mayor.get_entry_at(11 * 60), "before eight he is where yesterday ended")

func test_koyo_can_be_talked_to_from_the_first_morning() -> void:
	var koyo := MFarmNpcData.find(&"koyo")
	assert_true(koyo.get_entry_at(GameDefinition.current().start_minute_of_day).interactable, "the old game opened her stall only at 3:00 the next day")
	assert_eq(koyo.shop_bag_id, &"koyo_shop")

func test_the_clock_face_counts_the_old_calendar() -> void:
	assert_eq(MFarmTimePanel.date_text(1), "2023.01.01")
	assert_eq(MFarmTimePanel.date_text(31), "2023.02.01")
	assert_eq(MFarmTimePanel.date_text(361), "2024.01.01")
	assert_eq(MFarmTimePanel.lit_blocks(0), 1)
	assert_eq(MFarmTimePanel.lit_blocks(4), 2, "the old dial skipped from none to two blocks at four")
	assert_eq(MFarmTimePanel.lit_blocks(23), 6)
	assert_eq(GameCalendar.current().get_season_index(91), 1, "three months of thirty days to a season")

func _slot_of(item_id: StringName) -> int:
	return _slot_in(Bags.PLAYER, item_id)

func _slot_in(bag_key: StringName, item_id: StringName) -> int:
	var slots := Bags.get_slots(bag_key)
	for index: int in slots.size():
		if slots[index].item == item_id:
			return index
	return -1
