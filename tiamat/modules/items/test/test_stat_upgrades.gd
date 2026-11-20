extends GutTest

## Lasting upgrades (`StatUpgradeData`): what a level costs and does, the
## world that keeps them, their rule keys and the stand the player buys them
## at (`StatUpgradeStand`).

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const STAND_SCENE := preload("res://tiamat/modules/items/upgrades/stat_upgrade_stand.tscn")
const SPEED := TopDownPlayer.MOVE_SPEED_STAT

var _world: Dictionary
var _inventory: Dictionary
var _wallet: Dictionary

func before_each() -> void:
	_world = WorldState.to_save_data()
	_inventory = InventoryState.to_save_data()
	_wallet = Wallet.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	Wallet.set_money(0)
	var ore := ItemData.new()
	ore.id = &"fixture_ore"
	ore.display_name = "Ore"
	ContentFixture.use(self, [
		ore,
		_upgrade(&"fixture_boots", "Boots", 3, PackedInt32Array([10, 20]), {}, {SPEED: 1.5}),
		_upgrade(&"fixture_pack", "Pack", 1, PackedInt32Array([5]), {&"fixture_ore": 2}, {}, {SPEED: 10.0}),
		_upgrade(&"fixture_crown", "Crown", 1, PackedInt32Array(), {}, {SPEED: 2.0}, {}, "WORLD_FLAG test:crown"),
	])

func after_each() -> void:
	InputLock.clear()
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world)
	InventoryState.load_save_data(_inventory)
	Wallet.load_save_data(_wallet)

func _upgrade(upgrade_id: StringName, upgrade_name: String, levels: int, costs: PackedInt32Array, materials: Dictionary, multipliers: Dictionary, bonuses: Dictionary = {}, condition := "") -> StatUpgradeData:
	var upgrade := StatUpgradeData.new()
	upgrade.id = upgrade_id
	upgrade.display_name = upgrade_name
	upgrade.description = "%s upgrade" % upgrade_name
	upgrade.max_level = levels
	upgrade.money_costs = costs
	upgrade.materials.assign(materials)
	upgrade.multipliers.assign(multipliers)
	upgrade.bonuses.assign(bonuses)
	upgrade.condition = condition
	return upgrade

func test_each_level_costs_more_and_changes_stats_once_more() -> void:
	var boots := StatUpgradeData.find(&"fixture_boots")
	assert_eq(boots.get_next_cost(), 10)
	assert_eq(boots.get_buy_problem(), "Needs: 10g")
	assert_false(boots.buy(), "the player cannot pay")
	Wallet.set_money(100)
	watch_signals(ItemsEvents)
	assert_true(boots.buy())
	assert_signal_emitted_with_parameters(ItemsEvents, "stat_upgraded", [&"fixture_boots", 1])
	assert_eq(Wallet.money, 90)
	assert_eq(boots.get_next_cost(), 20)
	assert_true(boots.buy())
	assert_eq(boots.get_next_cost(), 20, "a level past the list costs as much as the last")
	assert_true(boots.buy())
	assert_eq(Wallet.money, 50)
	assert_eq(boots.get_level(), 3)
	assert_true(boots.is_maxed())
	assert_eq(boots.get_buy_problem(), "Fully upgraded")
	assert_false(boots.buy())
	assert_eq(Wallet.money, 50, "a maxed upgrade takes nothing")
	assert_almost_eq(GameStats.get_multiplier(SPEED), pow(1.5, 3), 0.001)
	WorldState.clear()
	assert_almost_eq(GameStats.get_multiplier(SPEED), 1.0, 0.001, "the upgrades live in the world")

func test_an_upgrade_costs_items_too() -> void:
	var pack := StatUpgradeData.find(&"fixture_pack")
	Wallet.set_money(5)
	assert_eq(pack.describe_cost(), "5g, Ore x2")
	assert_eq(pack.get_buy_problem(), "Needs: Ore x2")
	InventoryState.add_item_by_id(&"fixture_ore", 3)
	assert_true(pack.buy())
	assert_eq(InventoryState.get_quantity(&"fixture_ore"), 1)
	assert_eq(Wallet.money, 0)
	assert_almost_eq(GameStats.get_bonus(SPEED), 10.0, 0.001)

func test_a_locked_upgrade_says_what_it_needs_and_content_gives_a_level() -> void:
	var crown := StatUpgradeData.find(&"fixture_crown")
	assert_string_starts_with(crown.get_buy_problem(), "Locked: ")
	assert_false(GameRules.check("STAT_UPGRADE_AT_LEAST fixture_crown 1"))
	assert_true(GameRules.run_actions(PackedStringArray(["RAISE_STAT_UPGRADE fixture_crown"])), "content gives a level even while it is locked")
	assert_true(GameRules.check("STAT_UPGRADE_AT_LEAST fixture_crown 1"))
	assert_false(GameRules.run_actions(PackedStringArray(["RAISE_STAT_UPGRADE fixture_crown"])), "not past its last level")
	assert_eq(GameRules.describe("STAT_UPGRADE_AT_LEAST fixture_boots 2"), PackedStringArray(["Boots level 2"]))

func test_the_stand_lists_its_upgrades_and_buys_the_one_picked() -> void:
	Wallet.set_money(15)
	var stand := STAND_SCENE.instantiate() as StatUpgradeStand
	add_child_autofree(stand)
	watch_signals(stand)
	var outcome := {}
	(func() -> void: outcome["bought"] = await stand.browse()).call()
	var menu := stand.get_choice_menu()
	assert_eq((menu.get_node("%Title") as Label).text, "Upgrades")
	assert_eq(menu.get_choice_ids(), [&"fixture_boots", &"fixture_crown", &"fixture_pack"] as Array[StringName])
	assert_eq(menu.get_button(&"fixture_boots").text, "Boots (level 0 of 3)")
	assert_eq(menu.get_note(&"fixture_boots"), "Boots upgrade\nEach level: Move speed +50%\nNext level: 10g")
	assert_eq(menu.get_note(&"fixture_pack"), "Pack upgrade\nMove speed +10\nNeeds: Ore x2", "one level says what it changes alone")
	assert_true(menu.get_button(&"fixture_crown").disabled, "a locked upgrade")
	assert_true(menu.get_button(&"fixture_pack").disabled, "one the player cannot pay")
	assert_true(menu.choose(&"fixture_boots"))
	assert_signal_emitted_with_parameters(stand, "upgrade_bought", [&"fixture_boots", 1])
	assert_true(menu.is_open(), "the list stays open for the next")
	assert_eq(menu.get_button(&"fixture_boots").text, "Boots (level 1 of 3)")
	assert_true(menu.get_button(&"fixture_boots").has_focus())
	assert_true(menu.get_button(&"fixture_boots").disabled, "5g left of the 20g the next level costs")
	menu.close()
	assert_eq(outcome.get("bought"), 1)
	stand.upgrade_ids = [&"fixture_pack", &"fixture_unknown"] as Array[StringName]
	assert_eq(stand.get_upgrades().map(func(upgrade: StatUpgradeData) -> StringName: return upgrade.id), [&"fixture_pack"])
	assert_eq(stand.find_scene_problems(ContentRegistry.active, null), PackedStringArray(["upgrade stand 'StatUpgradeStand' offers unknown upgrade 'fixture_unknown'"]))

func test_an_upgrade_names_itself_changes_a_stat_and_costs_what_exists() -> void:
	var broken := _upgrade(&"fixture_broken", "", 1, PackedInt32Array([-1, 2]), {&"fixture_nothing": 1}, {})
	assert_eq(broken.find_problems(ContentRegistry.active), PackedStringArray([
		"has no display name",
		"changes no stat",
		"costs less than nothing (-1)",
		"lists 2 money costs for 1 levels",
		"costs unknown item 'fixture_nothing'",
	]))
