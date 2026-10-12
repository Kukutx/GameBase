extends GutTest

## A tool upgrade on tools the test builds: it takes the tool, the materials
## and the money and gives the stronger tool in one step, in the inventory and
## in every hotbar slot that held the old one.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	var bar := ItemData.new()
	bar.id = &"fixture_bar"
	var upgrade := ToolUpgradeData.new()
	upgrade.id = &"fixture_pickaxe_upgrade"
	upgrade.source_item_id = &"fixture_pickaxe"
	upgrade.result_item_id = &"fixture_strong_pickaxe"
	upgrade.materials = {"fixture_bar": 2}
	upgrade.money_cost = 300
	ContentFixture.use(self, [
		_pickaxe(&"fixture_pickaxe", 1),
		_pickaxe(&"fixture_strong_pickaxe", 2),
		bar,
		upgrade,
	])
	InventoryState.clear()

func after_each() -> void:
	# GUT frees the fixture after this; restore against the game's content.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_an_upgrade_replaces_the_tool_in_inventory_and_hotbar_atomically() -> void:
	InventoryState.add_item_by_id(&"fixture_pickaxe", 1)
	InventoryState.add_item_by_id(&"fixture_bar", 2)
	PlayerState.money = 500
	Hotbar.set_slot_item(2, &"fixture_pickaxe")

	assert_true(UpgradeState.upgrade(&"fixture_pickaxe_upgrade"))
	assert_eq(InventoryState.get_quantity(&"fixture_pickaxe"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_strong_pickaxe"), 1)
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 0)
	assert_eq(PlayerState.money, 200)
	assert_eq(Hotbar.slots[2], &"fixture_strong_pickaxe")

func _pickaxe(id: StringName, power: int) -> ItemData:
	var pickaxe := ItemData.new()
	pickaxe.id = id
	pickaxe.kind = ItemData.Kind.TOOL
	pickaxe.tool_action = MiningNode.TOOL_ACTION
	pickaxe.tool_power = power
	pickaxe.max_stack = 1
	return pickaxe
