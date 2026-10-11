extends GutTest

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _skills_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_skills_snapshot = Skills.to_save_data()
	InventoryState.clear()
	PlayerState.reset_new_game()
	Skills.reset_new_game()
	InventoryState.add_item_by_id(&"pickaxe", 1)
	InventoryState.add_item_by_id(&"copper_bar", 2)
	PlayerState.money = 1000

func after_each() -> void:
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skills_snapshot)

func test_upgrade_blocks_money_callback_reentrancy() -> void:
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(_money: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = UpgradeState.upgrade(&"copper_pickaxe_upgrade")
	PlayerState.money_changed.connect(reenter)
	assert_true(UpgradeState.upgrade(&"copper_pickaxe_upgrade"))
	if PlayerState.money_changed.is_connected(reenter):
		PlayerState.money_changed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(PlayerState.money, 700)
	assert_eq(InventoryState.get_quantity(&"pickaxe"), 0)
	assert_eq(InventoryState.get_quantity(&"copper_bar"), 0)
	assert_eq(InventoryState.get_quantity(&"copper_pickaxe"), 1)

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
		InventoryState.remove_item(&"copper_bar", 2)
	InventoryState.item_added.connect(on_added)
	InventoryState.item_removed.connect(on_removed)
	UpgradeState.tool_upgraded.connect(on_upgraded)
	PlayerState.money_changed.connect(sabotage)

	assert_false(UpgradeState.upgrade(&"copper_pickaxe_upgrade"))
	assert_eq(PlayerState.money, 1000)
	assert_eq(InventoryState.get_quantity(&"pickaxe"), 1)
	assert_eq(InventoryState.get_quantity(&"copper_pickaxe"), 0)
	assert_eq(InventoryState.get_quantity(&"copper_bar"), 0)
	# The only removal signal belongs to the deliberate sabotage; the failed
	# upgrade itself emitted no inventory transaction signals.
	assert_eq(int(observed["removed"]), 1)
	assert_eq(int(observed["added"]), 0)
	assert_eq(int(observed["upgraded"]), 0)

	if PlayerState.money_changed.is_connected(sabotage):
		PlayerState.money_changed.disconnect(sabotage)
	InventoryState.add_item_by_id(&"copper_bar", 2)
	observed["added"] = 0
	observed["removed"] = 0
	assert_true(UpgradeState.upgrade(&"copper_pickaxe_upgrade"))
	assert_eq(PlayerState.money, 700)
	assert_eq(InventoryState.get_quantity(&"pickaxe"), 0)
	assert_eq(InventoryState.get_quantity(&"copper_bar"), 0)
	assert_eq(InventoryState.get_quantity(&"copper_pickaxe"), 1)
	assert_eq(int(observed["removed"]), 2)
	assert_eq(int(observed["added"]), 1)
	assert_eq(int(observed["upgraded"]), 1)

	if InventoryState.item_added.is_connected(on_added):
		InventoryState.item_added.disconnect(on_added)
	if InventoryState.item_removed.is_connected(on_removed):
		InventoryState.item_removed.disconnect(on_removed)
	if UpgradeState.tool_upgraded.is_connected(on_upgraded):
		UpgradeState.tool_upgraded.disconnect(on_upgraded)
