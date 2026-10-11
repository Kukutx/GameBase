extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

const GARDEN := &"fixture_garden"
const WORKSHOP := &"fixture_workshop"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	ContentFixture.use(self, _content())
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()

func after_each() -> void:
	# The game's content is active again before the stores load their items.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_project_chain_donates_materials_unlocks_the_next_and_rewards_once() -> void:
	assert_true(TownProjects.is_available(GARDEN))
	assert_false(TownProjects.is_available(WORKSHOP))
	assert_eq(TownProjects.contribute_all_available(WORKSHOP), 0, "a locked project takes no donations")

	InventoryState.add_item_by_id(&"fixture_radish", 3)
	InventoryState.add_item_by_id(&"fixture_twig", 12)
	assert_eq(TownProjects.contribute_all_available(GARDEN), 13)
	assert_eq(InventoryState.get_quantity(&"fixture_twig"), 2, "only what the project still needs is donated")
	assert_true(TownProjects.is_completed(GARDEN))
	assert_true(GameRules.check("PROJECT_COMPLETED %s" % GARDEN))
	assert_true(TownProjects.is_available(WORKSHOP))
	var money_before := PlayerState.money
	assert_true(TownProjects.claim_reward(GARDEN))
	assert_eq(PlayerState.money, money_before + 600)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 6)
	assert_false(TownProjects.claim_reward(GARDEN))
	assert_eq(TownProjects.contribute_all_available(GARDEN), 0, "a completed project takes no donations")

	InventoryState.add_item_by_id(&"fixture_bar", 3)
	InventoryState.add_item_by_id(&"fixture_twig", 3)
	assert_eq(TownProjects.contribute_all_available(WORKSHOP), 8)
	assert_true(TownProjects.is_completed(WORKSHOP))
	assert_true(GameRules.check("PROJECT_COMPLETED %s" % WORKSHOP))
	assert_true(TownProjects.claim_reward(WORKSHOP))
	assert_eq(InventoryState.get_quantity(&"fixture_kit"), 1)

func test_project_reward_claim_blocks_item_added_reentrancy() -> void:
	WorldState.set_value(TownProjectService.STATE_KEY, {
		"fixture_garden": {
			"progress": {},
			"completed": true,
			"claimed": false,
			"completed_day": WorldClock.day,
			"claimed_day": 0,
		},
	})
	var money_before := PlayerState.money
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_seeds" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = TownProjects.claim_reward(GARDEN)
	InventoryState.item_added.connect(reenter)
	assert_true(TownProjects.claim_reward(GARDEN))
	if InventoryState.item_added.is_connected(reenter):
		InventoryState.item_added.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(TownProjects.is_claimed(GARDEN))
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 6)
	assert_eq(PlayerState.money, money_before + 600)

func test_completed_project_grants_the_reward_promised_at_completion() -> void:
	WorldState.set_value(TownProjectService.STATE_KEY, {
		"fixture_garden": {
			"progress": {},
			"completed": true,
			"claimed": false,
			"completed_day": WorldClock.day,
			"claimed_day": 0,
			"reward_snapshot": {"items": {"fixture_twig": 3, "removed_item": 2}, "money": 999},
		},
	})
	var money_before := PlayerState.money
	assert_true(TownProjects.claim_reward(GARDEN))
	assert_eq(PlayerState.money, money_before + 999)
	assert_eq(InventoryState.get_quantity(&"fixture_twig"), 3)
	assert_eq(InventoryState.get_quantity(&"removed_item"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 0)

func test_project_contribution_blocks_item_removed_reentrancy() -> void:
	InventoryState.add_item_by_id(&"fixture_radish", 2)
	var observed := {"entered": false, "inner_donated": -1}
	var reenter := func(_item_id: StringName, _quantity: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_donated"] = TownProjects.contribute(GARDEN, &"fixture_radish", 1)
	InventoryState.item_removed.connect(reenter)
	assert_eq(TownProjects.contribute(GARDEN, &"fixture_radish", 1), 1)
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_eq(int(observed["inner_donated"]), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_radish"), 1)
	assert_eq(TownProjects.get_progress(GARDEN, &"fixture_radish"), 1)
	assert_eq(TownProjects.contribute(GARDEN, &"fixture_radish", 1), 1)
	assert_eq(InventoryState.get_quantity(&"fixture_radish"), 0)
	assert_eq(TownProjects.get_progress(GARDEN, &"fixture_radish"), 2)

func test_project_state_sanitizes_malformed_nested_values_and_reward_snapshot() -> void:
	WorldState.set_value(TownProjectService.STATE_KEY, {
		"fixture_garden": {
			"progress": {"fixture_radish": {"bad": true}, "fixture_twig": -3, "fixture_bar": 2},
			"completed": {"truthy": true},
			"claimed": false,
			"completed_day": {"bad": true},
			"claimed_day": [9],
			"reward_snapshot": {"items": {"retired": {"quantity": {"bad": true}}}, "money": {"bad": true}},
		},
	})
	assert_eq(TownProjects.get_progress(GARDEN, &"fixture_radish"), 0)
	assert_eq(TownProjects.get_progress(GARDEN, &"fixture_twig"), 0)
	assert_eq(TownProjects.get_progress(GARDEN, &"fixture_bar"), 2)
	assert_false(TownProjects.is_completed(GARDEN))
	var normalized := TownProjects.get_state(GARDEN)
	assert_eq(int(normalized.get("completed_day", -1)), 0)
	assert_eq(int(normalized.get("claimed_day", -1)), 0)

	# A genuinely completed state with corrupted reward metadata remains claimable
	# without crashing; unreadable reward values are safely treated as zero.
	var raw_all := WorldState.get_value(TownProjectService.STATE_KEY, {}) as Dictionary
	var raw_project := (raw_all["fixture_garden"] as Dictionary).duplicate(true)
	raw_project["completed"] = true
	raw_all["fixture_garden"] = raw_project
	WorldState.set_value(TownProjectService.STATE_KEY, raw_all)
	assert_true(TownProjects.claim_reward(GARDEN))
	assert_true(TownProjects.is_claimed(GARDEN))
	assert_eq(InventoryState.get_quantity(&"retired"), 0)

func test_town_project_state_round_trips_with_world_state() -> void:
	InventoryState.add_item_by_id(&"fixture_radish", 2)
	assert_eq(TownProjects.contribute(GARDEN, &"fixture_radish", 2), 2)
	var snapshot := WorldState.to_save_data()
	WorldState.clear()
	assert_eq(TownProjects.get_progress(GARDEN, &"fixture_radish"), 0)
	WorldState.load_save_data(snapshot)
	assert_eq(TownProjects.get_progress(GARDEN, &"fixture_radish"), 2)

func test_project_completion_visual_follows_its_project() -> void:
	var host := ProjectCompletionVisual.new()
	host.project_id = GARDEN
	host.pending_text = "Pending"
	host.completed_text = "Complete"
	var visual := Polygon2D.new()
	visual.name = "Visual"
	host.add_child(visual)
	var label := Label.new()
	label.name = "Label"
	host.add_child(label)
	add_child_autofree(host)
	await get_tree().process_frame
	assert_eq(label.text, "Pending")
	assert_eq(visual.color, host.pending_color)
	InventoryState.add_item_by_id(&"fixture_radish", 3)
	InventoryState.add_item_by_id(&"fixture_twig", 10)
	TownProjects.contribute_all_available(GARDEN)
	assert_eq(label.text, "Complete")
	assert_eq(visual.color, host.completed_color)
	WorldState.clear()
	assert_eq(label.text, "Pending", "a new game or a load replaces the projects' state")

## A garden, then a workshop that needs the garden done first.
func _content() -> Array:
	var garden := TownProjectData.new()
	garden.id = GARDEN
	garden.display_name = "Fixture Garden"
	garden.requirements = {"fixture_radish": 3, "fixture_twig": 10}
	garden.reward_money = 600
	garden.reward_items = {"fixture_seeds": 6}
	var workshop := TownProjectData.new()
	workshop.id = WORKSHOP
	workshop.display_name = "Fixture Workshop"
	workshop.prerequisites = [GARDEN]
	workshop.requirements = {"fixture_bar": 3, "fixture_twig": 5}
	workshop.reward_items = {"fixture_kit": 1}
	var content: Array = [garden, workshop]
	for item_id: StringName in [&"fixture_radish", &"fixture_twig", &"fixture_bar", &"fixture_seeds", &"fixture_kit"]:
		var item := ItemData.new()
		item.id = item_id
		item.display_name = String(item_id).capitalize()
		content.append(item)
	return content
