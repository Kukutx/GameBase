extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

const UPGRADE := &"fixture_pick_upgrade"

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	var upgrade := ToolUpgradeData.new()
	upgrade.id = UPGRADE
	upgrade.display_name = "Better Pick"
	upgrade.source_item_id = &"fixture_pick"
	upgrade.result_item_id = &"fixture_better_pick"
	upgrade.materials = {"fixture_bar": 2}
	upgrade.money_cost = 300
	var bar := ItemData.new()
	bar.id = &"fixture_bar"
	bar.display_name = "Bar"
	ContentFixture.use(self, [upgrade, _tool(&"fixture_pick", 1), _tool(&"fixture_better_pick", 2), bar])
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	InventoryState.add_item_by_id(&"fixture_pick", 1)
	InventoryState.add_item_by_id(&"fixture_bar", 2)
	Wallet.money = 1000

func after_each() -> void:
	# The game's content is active again before the stores load their items.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_upgrade_blocks_money_callback_reentrancy() -> void:
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(_money: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = UpgradeState.upgrade(UPGRADE)
	Wallet.money_changed.connect(reenter)
	assert_true(UpgradeState.upgrade(UPGRADE))
	if Wallet.money_changed.is_connected(reenter):
		Wallet.money_changed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(Wallet.money, 700)
	assert_eq(InventoryState.get_quantity(&"fixture_pick"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_better_pick"), 1)

func test_upgrade_inventory_commit_is_atomic_after_money_side_effects() -> void:
	var observed := {"added": 0, "removed": 0, "upgraded": 0, "sabotaged": false}
	var on_added := func(_item_id: StringName, _quantity: int) -> void:
		observed["added"] = int(observed["added"]) + 1
	var on_removed := func(_item_id: StringName, _quantity: int) -> void:
		observed["removed"] = int(observed["removed"]) + 1
	var on_upgraded := func(_upgrade_id: StringName, _source_id: StringName, _result_id: StringName) -> void:
		observed["upgraded"] = int(observed["upgraded"]) + 1
	var sabotage := func(_money: int) -> void:
		if bool(observed["sabotaged"]):
			return
		observed["sabotaged"] = true
		InventoryState.remove_item(&"fixture_bar", 2)
	InventoryState.item_added.connect(on_added)
	InventoryState.item_removed.connect(on_removed)
	UpgradeState.tool_upgraded.connect(on_upgraded)
	Wallet.money_changed.connect(sabotage)

	assert_false(UpgradeState.upgrade(UPGRADE))
	assert_eq(Wallet.money, 1000)
	assert_eq(InventoryState.get_quantity(&"fixture_pick"), 1)
	assert_eq(InventoryState.get_quantity(&"fixture_better_pick"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 0)
	# The only removal signal belongs to the deliberate sabotage; the failed
	# upgrade itself emitted no inventory transaction signals.
	assert_eq(int(observed["removed"]), 1)
	assert_eq(int(observed["added"]), 0)
	assert_eq(int(observed["upgraded"]), 0)

	if Wallet.money_changed.is_connected(sabotage):
		Wallet.money_changed.disconnect(sabotage)
	InventoryState.add_item_by_id(&"fixture_bar", 2)
	observed["added"] = 0
	observed["removed"] = 0
	assert_true(UpgradeState.upgrade(UPGRADE))
	assert_eq(Wallet.money, 700)
	assert_eq(InventoryState.get_quantity(&"fixture_pick"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_better_pick"), 1)
	assert_eq(int(observed["removed"]), 2)
	assert_eq(int(observed["added"]), 1)
	assert_eq(int(observed["upgraded"]), 1)

	if InventoryState.item_added.is_connected(on_added):
		InventoryState.item_added.disconnect(on_added)
	if InventoryState.item_removed.is_connected(on_removed):
		InventoryState.item_removed.disconnect(on_removed)
	if UpgradeState.tool_upgraded.is_connected(on_upgraded):
		UpgradeState.tool_upgraded.disconnect(on_upgraded)

func _tool(id: StringName, power: int) -> ItemData:
	var tool := ItemData.new()
	tool.id = id
	tool.display_name = String(id).capitalize()
	tool.kind = ItemData.Kind.TOOL
	tool.max_stack = 1
	tool.tool_action = MiningNode.TOOL_ACTION
	tool.tool_power = power
	return tool
