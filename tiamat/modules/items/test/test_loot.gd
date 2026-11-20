extends GutTest

## What a find holds (`LootTable`) and a chest that holds one (`LootChest`):
## what it draws, at what level, and how the player takes it.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const CHEST_SCENE := preload("res://tiamat/modules/items/loot/loot_chest.tscn")

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _wallet_snapshot: Dictionary
var _inventory_slots: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_wallet_snapshot = Wallet.to_save_data()
	_inventory_slots = InventoryState.max_slots
	var items: Array[ContentEntry] = []
	for spec: Array in [[&"fixture_stone", "Stone", 5], [&"fixture_gem", "Gem", 99], [&"fixture_crown", "Crown", 1]]:
		var item := ItemData.new()
		item.id = spec[0]
		item.display_name = spec[1]
		item.max_stack = spec[2]
		items.append(item)
	ContentFixture.use(self, items)
	WorldState.clear()
	InventoryState.clear()
	Wallet.set_money(0)

func after_each() -> void:
	ContentRegistry.active = ContentDB
	InventoryState.max_slots = _inventory_slots
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_wallet_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_a_find_draws_its_picks_by_weight_from_what_its_level_reached() -> void:
	var table := LootTable.new()
	table.entries = [LootEntry.of(&"fixture_stone", [2, 4]), LootEntry.of(&"fixture_gem"), LootEntry.of(&"fixture_crown", 1, 1.0, 5), LootEntry.of(&"fixture_none", 1, 0.0)] as Array[LootEntry]
	table.picks = 3
	for index: int in 20:
		var find := table.roll(_rolls("draw%d" % index), 1)
		assert_eq(find.items.size(), 2, "as many picks as entries came by its level, each once")
		assert_between(find.items[&"fixture_stone"], 2, 4, "each its count between its least and most")
		assert_eq(find.items[&"fixture_gem"], 1)
		assert_false(find.items.has(&"fixture_none"), "a weight of 0 never comes")
		assert_eq(find.money, 0, "no money where it holds none")
	assert_true(table.roll(_rolls("deep"), 5).items.has(&"fixture_crown"), "an entry comes from its level on")
	table.picks = 1
	var first := table.roll(_rolls("same"), 5)
	assert_eq(first.items.size(), 1)
	assert_eq(table.roll(_rolls("same"), 5).items, first.items, "the same rolls find the same")
	assert_eq(table.get_item_ids(), [&"fixture_stone", &"fixture_gem", &"fixture_crown"] as Array[StringName], "what it may hold, at any level")

func test_its_money_grows_with_the_level() -> void:
	var table := LootTable.new()
	table.money_min = 10
	table.money_max = 10
	table.money_per_level = 2.0
	assert_eq(table.roll(_rolls("money"), 1).money, 10, "its range at the first level")
	assert_eq(table.roll(_rolls("money"), 6).money, 20, "and more each level past it")
	table.money_max = 30
	for index: int in 10:
		assert_between(table.roll(_rolls("range%d" % index), 0).money, 10, 30)
	assert_true(table.roll(_rolls("money"), 1).items.is_empty(), "a table of money only finds no items")

func test_a_find_reads_and_saves() -> void:
	var find := LootTable.Find.new()
	assert_true(find.is_empty())
	find.items[&"fixture_stone"] = 3
	find.items[&"fixture_gem"] = 1
	find.money = 24
	assert_false(find.is_empty())
	assert_eq(find.describe(), GameText.list(PackedStringArray(["Stone x3", "Gem", "24g"])), "each item named, with its count past one, and its money")
	var again := LootTable.Find.from_save_data(JSON.parse_string(JSON.stringify(find.to_save_data())))
	assert_eq(again.items, find.items, "it comes back from a save")
	assert_eq(again.money, 24)
	assert_true(LootTable.Find.from_save_data("broken").is_empty(), "nothing from what is no find")

func test_a_table_finds_its_problems() -> void:
	var table := LootTable.new()
	table.entries = [LootEntry.of(&"fixture_stone", [1, 3])] as Array[LootEntry]
	assert_eq(table.find_problems(ContentRegistry.active), PackedStringArray())
	var odd := LootEntry.of(&"fixture_gem", [4, 2])
	table.entries = [LootEntry.of(&"fixture_missing"), odd, null] as Array[LootEntry]
	table.money_min = 5
	assert_eq(table.find_problems(ContentRegistry.active).size(), 4, "an unknown item, fewer at most than at least, no item, less money at most than at least")
	assert_eq(LootTable.new().find_problems(ContentRegistry.active).size(), 1, "and a table that finds nothing")

func test_a_chest_gives_what_the_bag_holds_and_keeps_the_rest() -> void:
	InventoryState.max_slots = 1
	var chest := _add_chest(_table(7, 12))
	watch_signals(ItemsEvents)
	chest.locked = true
	assert_false(chest.interactable.enabled, "a locked chest stays shut")
	assert_true(chest.open().is_empty())
	assert_false(chest.is_opened())
	chest.locked = false
	assert_true(chest.interactable.enabled)
	var taken := chest.open()
	assert_eq(taken.items, {&"fixture_stone": 5} as Dictionary[StringName, int], "as much as the bag holds")
	assert_eq(taken.money, 12)
	assert_eq(Wallet.money, 12, "its money goes to the wallet")
	assert_eq(chest.get_contents().items, {&"fixture_stone": 2} as Dictionary[StringName, int], "the rest stays in the chest")
	assert_true(chest.interactable.enabled, "for later")
	InventoryState.clear()
	chest.interactable.interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_stone"), 2)
	assert_true(chest.is_emptied())
	assert_false(chest.interactable.enabled, "an emptied chest takes no more")
	assert_eq(Wallet.money, 12, "its money is given once")
	var opened_count: int = get_signal_emit_count(ItemsEvents, "chest_opened")
	assert_eq(opened_count, 1, "it tells it opened the first time only")

func test_a_persistent_chest_keeps_what_it_holds() -> void:
	InventoryState.max_slots = 1
	var chest := _add_chest(_table(7), &"fixture_chest")
	var contents := chest.get_contents().items.duplicate()
	assert_eq(_add_chest(_table(7), &"fixture_chest").get_contents().items, contents, "an unfilled chest rolls the same from its key")
	assert_eq(chest.get_persistent_keys(), PackedStringArray(["chest:fixture_chest"]))
	chest.open()
	var again := _add_chest(_table(7), &"fixture_chest")
	assert_true(again.is_opened(), "an opened chest stays open")
	assert_eq(again.get_contents().items, {&"fixture_stone": 2} as Dictionary[StringName, int], "with what it still held")
	InventoryState.clear()
	again.open()
	assert_true(_add_chest(_table(7), &"fixture_chest").is_emptied(), "and an emptied one stays empty")

func test_a_chest_is_filled_once_by_its_place() -> void:
	var table := LootTable.new()
	table.entries = [LootEntry.of(&"fixture_gem", [1, 9])] as Array[LootEntry]
	table.picks = 1
	var chest := _add_chest(table)
	chest.level = 3
	chest.fill(_rolls("place"))
	assert_eq(chest.get_contents().items, table.roll(_rolls("place"), 3).items, "from the place's stream at its level")
	chest.open()
	chest.fill(_rolls("other"))
	assert_true(chest.is_emptied(), "an opened chest is not filled again")
	assert_eq(_add_chest(null).find_scene_problems(ContentRegistry.active, null).size(), 1, "a chest needs something to hold")
	assert_eq(chest.find_scene_problems(ContentRegistry.active, null), PackedStringArray())

func test_a_chest_spread_says_which_floors_hold_one() -> void:
	var spread := ChestSpread.new()
	assert_false(spread.holds_chest(_rolls("none"), 5), "none without a table")
	spread.loot = _table(3)
	spread.from_level = 4
	spread.chance = 1.0
	assert_false(spread.holds_chest(_rolls("above"), 3), "none above its first level")
	assert_true(spread.holds_chest(_rolls("at"), 4))
	spread.chance = 0.25
	var held := 0
	for index: int in 400:
		if spread.holds_chest(_rolls("often%d" % index), 10):
			held += 1
	assert_between(held, 70, 130, "as often as its chance")
	spread.chance = 0.0
	assert_false(spread.holds_chest(_rolls("guarded"), 10, true), "a guarded floor holds none without a hoard")
	spread.hoard = _table(9, 50)
	spread.hoard_name = "Fixture Hoard"
	assert_true(spread.holds_chest(_rolls("guarded"), 1, true), "and always its hoard")
	var chest := spread.make(6)
	assert_eq([chest.name, chest.display_name, chest.loot, chest.level], [&"Chest", "Chest", spread.loot, 6])
	chest.free()
	var hoard := spread.make(6, true)
	assert_eq([hoard.name, hoard.display_name, hoard.loot, hoard.level], [&"Hoard", "Fixture Hoard", spread.hoard, 6], "the hoard on a guarded floor")
	hoard.free()
	var sources := ItemSources.new()
	spread.add_ways(sources, "In fixture chests")
	assert_eq(sources.get_ways(&"fixture_stone"), PackedStringArray(["In fixture chests"]), "a way to get what its chests hold")
	assert_eq(spread.find_problems(ContentRegistry.active), PackedStringArray())
	assert_eq(ChestSpread.new().find_problems(ContentRegistry.active).size(), 1, "a spread holds something")

func _table(stones: int, money := 0) -> LootTable:
	var table := LootTable.new()
	table.entries = [LootEntry.of(&"fixture_stone", stones)] as Array[LootEntry]
	table.money_min = money
	table.money_max = money
	return table

func _add_chest(loot: LootTable, id := &"") -> LootChest:
	var chest := CHEST_SCENE.instantiate() as LootChest
	chest.loot = loot
	chest.persistent_id = id
	add_child_autofree(chest)
	return chest

func _rolls(key: String) -> GameRandomStream:
	return GameRandomStream.new(("fixture_loot:" + key).sha256_buffer())
