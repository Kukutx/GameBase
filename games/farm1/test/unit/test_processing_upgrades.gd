extends GutTest

var _clock_day: int
var _clock_minute: int
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skills_snapshot: Dictionary

func before_each() -> void:
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skills_snapshot = Skills.to_save_data()
	InventoryState.clear()
	WorldState.clear()
	PlayerState.reset_new_game()
	Skills.reset_new_game()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	Skills.load_save_data(_skills_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)

func test_copper_rung_costs_and_tool_powers() -> void:
	var smelt := ProcessingRecipeData.find(&"smelt_copper_bar")
	assert_eq(smelt.inputs, {"copper_ore": 2, "wood": 1})
	assert_eq(smelt.output_item_id, &"copper_bar")
	assert_eq(smelt.output_quantity, 1)
	assert_eq(smelt.process_minutes, 60)
	var upgrade := ToolUpgradeData.find(&"copper_pickaxe_upgrade")
	assert_eq(upgrade.source_item_id, &"pickaxe")
	assert_eq(upgrade.result_item_id, &"copper_pickaxe")
	assert_eq(upgrade.materials, {"copper_bar": 2})
	assert_eq(upgrade.money_cost, 300)
	# Copper farm tools halve a plot's energy costs (hoe 4 -> 2, can 2 -> 1).
	assert_eq(ItemData.find(&"copper_hoe").tool_power, 2)
	assert_eq(ItemData.find(&"copper_watering_can").tool_power, 2)
	# A copper pickaxe breaks the starter stone in one hit.
	var stone := MiningNodeData.find(&"stone_rock")
	var copper_pickaxe := ItemData.find(&"copper_pickaxe")
	assert_gte(copper_pickaxe.tool_power, stone.required_tool_power)
	assert_gte(copper_pickaxe.tool_power, stone.durability)

func test_iron_bar_smelt_and_pickaxe_upgrade_extend_mining_progression() -> void:
	Skills.add_xp(&"mining", 250)
	assert_eq(Skills.get_level(&"mining"), 3)
	InventoryState.add_item_by_id(&"iron_ore", 3)
	InventoryState.add_item_by_id(&"wood", 1)
	var station_scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var furnace := station_scene.instantiate() as ProcessingStation
	furnace.station_id = &"test_iron_furnace"
	furnace.recipe_ids = [&"smelt_copper_bar", &"smelt_iron_bar"]
	add_child_autofree(furnace)
	await get_tree().process_frame
	assert_true(furnace.start_recipe(&"smelt_iron_bar"))
	assert_eq(InventoryState.get_quantity(&"iron_ore"), 0)
	assert_eq(furnace.get_minutes_remaining(), 90)
	WorldClock.set_time(1, 10 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"iron_bar"), 1)

	InventoryState.add_item_by_id(&"copper_pickaxe", 1)
	InventoryState.add_item_by_id(&"iron_bar", 2)
	PlayerState.money = 1400
	Hotbar.set_slot_item(2, &"copper_pickaxe")
	assert_true(UpgradeState.upgrade(&"iron_pickaxe_upgrade"))
	assert_eq(InventoryState.get_quantity(&"copper_pickaxe"), 0)
	assert_eq(InventoryState.get_quantity(&"iron_pickaxe"), 1)
	assert_eq(InventoryState.get_quantity(&"iron_bar"), 0)
	assert_eq(PlayerState.money, 0)
	assert_eq(Hotbar.slots[2], &"iron_pickaxe")
	assert_eq(ItemData.find(&"iron_pickaxe").tool_power, 3)

func test_oil_maker_crafts_and_processes_truffle_into_artisan_oil() -> void:
	Skills.add_xp(&"farming", 100)
	assert_eq(Skills.get_level(&"farming"), 2)
	InventoryState.add_item_by_id(&"copper_bar", 2)
	InventoryState.add_item_by_id(&"wood", 12)
	assert_true(CraftingState.craft(&"oil_maker"))
	assert_eq(InventoryState.get_quantity(&"oil_maker"), 1)
	var placeable := PlaceableData.find(&"oil_maker")
	assert_not_null(placeable)
	assert_eq(placeable.item_id, &"oil_maker")
	assert_true(ResourceLoader.exists(placeable.scene_path))

	InventoryState.add_item_by_id(&"truffle", 1)
	var machine_scene := load("res://game/world/placeables/oil_maker.tscn") as PackedScene
	var machine := machine_scene.instantiate() as ProcessingStation
	machine.station_id = &"test_oil_maker"
	add_child_autofree(machine)
	await get_tree().process_frame
	assert_true(machine.start_recipe(&"press_truffle_oil"))
	assert_eq(InventoryState.get_quantity(&"truffle"), 0)
	assert_eq(machine.get_minutes_remaining(), 180)
	WorldClock.set_time(1, 11 * 60)
	await get_tree().process_frame
	assert_true(machine.output_ready)
	assert_true(machine.collect_output())
	assert_eq(InventoryState.get_quantity(&"truffle_oil"), 1)
	assert_gt(ItemData.find(&"truffle_oil").sell_price, ItemData.find(&"truffle").sell_price)

func test_gold_bar_smelt_and_pickaxe_upgrade_complete_deep_mining_chain() -> void:
	Skills.add_xp(&"mining", 700)
	assert_eq(Skills.get_level(&"mining"), 5)
	InventoryState.add_item_by_id(&"gold_ore", 3)
	InventoryState.add_item_by_id(&"wood", 1)
	var station_scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var furnace := station_scene.instantiate() as ProcessingStation
	furnace.station_id = &"test_gold_furnace"
	furnace.recipe_ids = [&"smelt_copper_bar", &"smelt_iron_bar", &"smelt_gold_bar"]
	add_child_autofree(furnace)
	await get_tree().process_frame
	assert_true(furnace.start_recipe(&"smelt_gold_bar"))
	assert_eq(InventoryState.get_quantity(&"gold_ore"), 0)
	assert_eq(furnace.get_minutes_remaining(), 120)
	WorldClock.set_time(1, 10 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"gold_bar"), 1)

	InventoryState.add_item_by_id(&"iron_pickaxe", 1)
	InventoryState.add_item_by_id(&"gold_bar", 4)
	PlayerState.money = 4000
	Hotbar.set_slot_item(2, &"iron_pickaxe")
	assert_true(UpgradeState.upgrade(&"gold_pickaxe_upgrade"))
	assert_eq(InventoryState.get_quantity(&"iron_pickaxe"), 0)
	assert_eq(InventoryState.get_quantity(&"gold_pickaxe"), 1)
	assert_eq(InventoryState.get_quantity(&"gold_bar"), 0)
	assert_eq(PlayerState.money, 0)
	assert_eq(Hotbar.slots[2], &"gold_pickaxe")
	assert_eq(ItemData.find(&"gold_pickaxe").tool_power, 4)

func test_full_metal_tool_upgrade_catalog_is_chained_without_weapon_damage_regression() -> void:
	var expected := {
		&"iron_hoe_upgrade": [&"copper_hoe", &"iron_hoe", 3],
		&"iron_watering_can_upgrade": [&"copper_watering_can", &"iron_watering_can", 3],
		&"iron_pickaxe_upgrade": [&"copper_pickaxe", &"iron_pickaxe", 3],
		&"iron_sword_upgrade": [&"copper_sword", &"iron_sword", 36],
		&"gold_hoe_upgrade": [&"iron_hoe", &"gold_hoe", 4],
		&"gold_watering_can_upgrade": [&"iron_watering_can", &"gold_watering_can", 4],
		&"gold_pickaxe_upgrade": [&"iron_pickaxe", &"gold_pickaxe", 4],
		&"gold_sword_upgrade": [&"iron_sword", &"gold_sword", 52],
		&"iridium_hoe_upgrade": [&"gold_hoe", &"iridium_hoe", 5],
		&"iridium_watering_can_upgrade": [&"gold_watering_can", &"iridium_watering_can", 5],
		&"iridium_pickaxe_upgrade": [&"gold_pickaxe", &"iridium_pickaxe", 5],
		&"iridium_sword_upgrade": [&"gold_sword", &"iridium_sword", 72],
	}
	for raw_id: Variant in expected.keys():
		var upgrade_id := StringName(String(raw_id))
		var values: Array = expected[raw_id]
		var upgrade := ToolUpgradeData.find(upgrade_id)
		assert_not_null(upgrade)
		if upgrade == null:
			continue
		assert_eq(upgrade.source_item_id, values[0])
		assert_eq(upgrade.result_item_id, values[1])
		assert_eq(ItemData.find(upgrade.result_item_id).tool_power, int(values[2]))

func test_weapon_damage_increases_at_every_upgrade_tier() -> void:
	var damages := []
	for item_id: StringName in [&"rusty_sword", &"copper_sword", &"iron_sword", &"gold_sword", &"iridium_sword"]:
		var item := ItemData.find(item_id)
		assert_not_null(item)
		if item != null:
			damages.append(item.tool_power)
	assert_eq(damages, [15, 24, 36, 52, 72])
	for index in range(1, damages.size()):
		assert_gt(int(damages[index]), int(damages[index - 1]))

func test_iridium_bar_smelt_and_pickaxe_upgrade_complete_late_mining_chain() -> void:
	Skills.add_xp(&"mining", 1400)
	assert_eq(Skills.get_level(&"mining"), 7)
	InventoryState.add_item_by_id(&"iridium_ore", 4)
	InventoryState.add_item_by_id(&"wood", 1)
	var station_scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var furnace := station_scene.instantiate() as ProcessingStation
	furnace.station_id = &"test_iridium_furnace"
	furnace.recipe_ids = [&"smelt_iridium_bar"]
	add_child_autofree(furnace)
	await get_tree().process_frame
	assert_true(furnace.start_recipe(&"smelt_iridium_bar"))
	assert_eq(InventoryState.get_quantity(&"iridium_ore"), 0)
	assert_eq(furnace.get_minutes_remaining(), 180)
	WorldClock.set_time(1, 11 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"iridium_bar"), 1)

	InventoryState.add_item_by_id(&"gold_pickaxe", 1)
	InventoryState.add_item_by_id(&"iridium_bar", 4)
	PlayerState.money = 9000
	Hotbar.set_slot_item(2, &"gold_pickaxe")
	assert_true(UpgradeState.upgrade(&"iridium_pickaxe_upgrade"))
	assert_eq(InventoryState.get_quantity(&"gold_pickaxe"), 0)
	assert_eq(InventoryState.get_quantity(&"iridium_pickaxe"), 1)
	assert_eq(InventoryState.get_quantity(&"iridium_bar"), 0)
	assert_eq(PlayerState.money, 0)
	assert_eq(Hotbar.slots[2], &"iridium_pickaxe")
	assert_eq(ItemData.find(&"iridium_pickaxe").tool_power, 5)

func test_furnace_entry_points_expose_all_metal_recipes() -> void:
	var packed := load("res://game/world/placeables/copper_furnace.tscn") as PackedScene
	var placeable := packed.instantiate() as ProcessingStation
	add_child_autofree(placeable)
	await get_tree().process_frame
	for recipe_id: StringName in [&"smelt_copper_bar", &"smelt_iron_bar", &"smelt_gold_bar", &"smelt_iridium_bar"]:
		assert_true(placeable.recipe_ids.has(recipe_id))
	var riverside := load("res://game/world/riverside_town.tscn") as PackedScene
	var scene := riverside.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	var fixed_furnace := scene.get_node("CopperFurnace") as ProcessingStation
	for recipe_id: StringName in [&"smelt_copper_bar", &"smelt_iron_bar", &"smelt_gold_bar", &"smelt_iridium_bar"]:
		assert_true(fixed_furnace.recipe_ids.has(recipe_id))
