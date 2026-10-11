extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

const ARCHIVE := &"fixture_crop_archive"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()
	var archive := CollectionMilestoneData.new()
	archive.id = ARCHIVE
	archive.display_name = "Fixture Crops"
	archive.category = CollectionService.CROPS
	archive.reward_money = 500
	archive.reward_items = {"fixture_seeds": 6}
	ContentFixture.use(self, [
		archive,
		_crop(&"fixture_radish"),
		_crop(&"fixture_gourd"),
		_item(&"fixture_seeds"),
		_item(&"fixture_twig"),
	])

func after_each() -> void:
	# The game's content is active again before the stores load their items.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_archive_becomes_ready_claims_once_and_persists() -> void:
	assert_false(CollectionMilestones.is_ready(ARCHIVE))
	assert_false(GameRules.check("MILESTONE_CLAIMED %s" % ARCHIVE))
	_discover_every_crop()
	assert_true(CollectionMilestones.is_ready(ARCHIVE))
	assert_eq(CollectionMilestones.get_ready_count(), 1)
	var money_before := PlayerState.money
	assert_true(CollectionMilestones.claim(ARCHIVE))
	assert_true(CollectionMilestones.is_claimed(ARCHIVE))
	assert_true(GameRules.check("MILESTONE_CLAIMED %s" % ARCHIVE))
	assert_eq(PlayerState.money, money_before + 500)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 6)
	assert_false(CollectionMilestones.claim(ARCHIVE))

	var saved := WorldState.to_save_data()
	WorldState.clear()
	assert_false(CollectionMilestones.is_claimed(ARCHIVE))
	WorldState.load_save_data(saved)
	assert_true(CollectionMilestones.is_claimed(ARCHIVE))
	assert_false(CollectionMilestones.is_ready(ARCHIVE))

func test_archive_claim_blocks_item_added_reentrancy() -> void:
	_discover_every_crop()
	assert_true(CollectionMilestones.is_ready(ARCHIVE))
	var money_before := PlayerState.money
	var observed := {"entered": false, "inner_result": true}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_seeds" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = CollectionMilestones.claim(ARCHIVE)
	InventoryState.item_added.connect(listener)
	assert_true(CollectionMilestones.claim(ARCHIVE))
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(CollectionMilestones.is_claimed(ARCHIVE))
	assert_eq(PlayerState.money, money_before + 500)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 6)

func test_ready_archive_grants_the_reward_promised_when_it_became_ready() -> void:
	_discover_every_crop()
	assert_true(CollectionMilestones.is_ready(ARCHIVE))
	assert_true(WorldState.get_value(&"collection:milestone:fixture_crop_archive:reward_snapshot", {}) is Dictionary)
	WorldState.set_value(&"collection:milestone:fixture_crop_archive:reward_snapshot", {
		"items": {"fixture_twig": 2, "removed_item": 5},
		"money": 888,
	})
	var money_before := PlayerState.money
	assert_true(CollectionMilestones.claim(ARCHIVE))
	assert_eq(PlayerState.money, money_before + 888)
	assert_eq(InventoryState.get_quantity(&"fixture_twig"), 2)
	assert_eq(InventoryState.get_quantity(&"removed_item"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 0)

func test_qualified_milestone_stays_claimable_after_catalog_growth() -> void:
	assert_eq(CollectionState.get_discovered_count(CollectionService.CROPS), 0)
	WorldState.set_value(&"collection:milestone_qualified:fixture_crop_archive", true)
	WorldState.set_value(&"collection:milestone:fixture_crop_archive:reward_snapshot", {
		"items": {"fixture_twig": 1},
		"money": 321,
	})
	assert_true(CollectionMilestones.is_ready(ARCHIVE))
	var money_before := PlayerState.money
	assert_true(CollectionMilestones.claim(ARCHIVE))
	assert_eq(PlayerState.money, money_before + 321)
	assert_eq(InventoryState.get_quantity(&"fixture_twig"), 1)

func test_pure_prerequisite_milestones_require_claimed_dependencies() -> void:
	var milestone := CollectionMilestoneData.new()
	milestone.id = &"test_meta_archive"
	milestone.category = &""
	milestone.prerequisites = [ARCHIVE, &"fixture_fish_archive"]
	assert_false(bool(CollectionMilestones.call("_prerequisites_met", milestone)))
	WorldState.set_value(&"collection:milestone:fixture_crop_archive:claimed", true)
	assert_false(bool(CollectionMilestones.call("_prerequisites_met", milestone)))
	WorldState.set_value(&"collection:milestone:fixture_fish_archive:claimed", true)
	assert_true(bool(CollectionMilestones.call("_prerequisites_met", milestone)))

func _discover_every_crop() -> void:
	for item_id: StringName in CollectionState.get_total_ids(CollectionService.CROPS):
		CollectionState.record(CollectionService.CROPS, item_id, 1)

## A crop harvested as the item `item_id`.
func _crop(item_id: StringName) -> CropData:
	var crop := CropData.new()
	crop.id = StringName("%s_crop" % item_id)
	crop.harvest_item_id = item_id
	return crop

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
