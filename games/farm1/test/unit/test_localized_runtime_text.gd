extends GutTest

# The coverage gate proves that a translation entry exists. These tests show the
# other half: text that a service formats for the HUD and the menus is translated
# before it is formatted, so no untranslated word is left in what a player sees
# in Simplified Chinese.

var _locale_before := "en"
var _world_snapshot: Dictionary
var _skills_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _buffs_snapshot: Dictionary
var _untranslated_word := RegEx.create_from_string("[A-Za-z]{3,}")

func before_each() -> void:
	_locale_before = TranslationServer.get_locale()
	_world_snapshot = WorldState.to_save_data()
	_skills_snapshot = Skills.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_buffs_snapshot = BuffState.to_save_data()
	TranslationServer.set_locale("zh_CN")

func after_each() -> void:
	TranslationServer.set_locale(_locale_before)
	WorldState.load_save_data(_world_snapshot)
	Skills.load_save_data(_skills_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	BuffState.load_save_data(_buffs_snapshot)

func test_hud_summaries_are_translated() -> void:
	InventoryState.clear()
	_assert_translated(InventoryState.get_summary(2), "empty inventory summary")
	InventoryState.add_item_by_id(&"wood", 8)
	InventoryState.add_item_by_id(&"berry", 2)
	InventoryState.add_item_by_id(&"hay", 1)
	_assert_translated(InventoryState.get_summary(2), "inventory summary")
	_assert_translated(Skills.get_summary(), "skill summary")
	_assert_translated(Hotbar.get_text(), "hotbar")
	_assert_translated(QuestState.get_active_summary(), "active quest")
	_assert_translated(CollectionState.get_summary(), "collection summary")
	assert_true(BuffState.apply_buff(&"hearty_worker"))
	_assert_translated(BuffState.get_summary(), "buff summary")

func test_skill_passives_are_translated_at_every_tier() -> void:
	for skill: StringName in SkillManager.SKILL_IDS:
		_assert_translated(Skills.get_perk_summary(skill), "%s passive before Lv5" % skill)
	for skill: StringName in SkillManager.SKILL_IDS:
		Skills.add_xp(skill, 1000000)
		assert_eq(Skills.get_perk_tier(skill), 2)
		_assert_translated(Skills.get_perk_summary(skill), "%s passive at tier 2" % skill)

func test_daily_contract_text_is_translated_in_every_state() -> void:
	for objective: StringName in [DailyContractService.FORAGE, DailyContractService.FISH, DailyContractService.MINE, DailyContractService.SHIP, DailyContractService.HARVEST]:
		var state := _contract(objective)
		_assert_translated(DailyContractState.get_display_title(state), "%s contract title" % objective)
		_assert_translated(DailyContractState.get_display_description(state), "%s contract description" % objective)
	var offer := _contract(DailyContractService.SHIP)
	WorldState.set_value(DailyContractService.STATE_KEY, offer)
	_assert_translated(DailyContractState.get_summary(), "offered contract")
	offer["accepted"] = true
	WorldState.set_value(DailyContractService.STATE_KEY, offer)
	_assert_translated(DailyContractState.get_summary(), "accepted contract")
	offer["completed"] = true
	offer["progress"] = 2
	WorldState.set_value(DailyContractService.STATE_KEY, offer)
	_assert_translated(DailyContractState.get_summary(), "completed contract")
	offer["claimed"] = true
	WorldState.set_value(DailyContractService.STATE_KEY, offer)
	_assert_translated(DailyContractState.get_summary(), "claimed contract")

func test_project_and_milestone_summaries_are_translated() -> void:
	for project: TownProjectData in ContentDB.get_all_town_projects():
		_assert_translated(TownProjects.get_project_summary(project.id), "project %s" % project.id)
	_assert_translated(TownProjects.get_project_summary(&"missing_project"), "unknown project")
	for milestone: CollectionMilestoneData in CollectionMilestones.get_all_milestones():
		_assert_translated(CollectionMilestones.get_summary(milestone), "milestone %s" % milestone.id)
	for category: StringName in CollectionService.CATEGORIES:
		_assert_translated(CollectionState.get_category_name(category), "category %s" % category)

func test_save_and_load_results_are_translated() -> void:
	# The test runner has no playable location, so saving is blocked and loading
	# an empty slot fails; both report a reason to the player.
	var manager := GameSaveManager.new()
	add_child_autofree(manager)
	manager.save_directory = "user://test_localized_text"
	manager.select_slot(1)
	var messages: Array[String] = []
	manager.save_completed.connect(func(_success: bool, message: String) -> void: messages.append(message))
	manager.load_completed.connect(func(_success: bool, message: String) -> void: messages.append(message))
	_assert_translated(manager.get_save_block_reason(), "save block reason")
	assert_false(manager.save_game())
	assert_false(await manager.load_game())
	assert_eq(messages.size(), 2)
	for message: String in messages:
		_assert_translated(message, "save or load result")

func test_npc_schedule_activities_are_translated() -> void:
	var checked := 0
	for profile: NpcProfileData in ContentDB.get_all_npcs():
		for entry: NpcScheduleEntry in profile.schedule_entries:
			_assert_translated(tr(entry.activity), "activity of %s" % profile.id)
			checked += 1
	assert_gt(checked, 0)

func _contract(objective: StringName) -> Dictionary:
	return {
		"objective_type": String(objective),
		"target_item_id": "berry",
		"required": 2,
		"reward_money": 100,
		"generated_day": WorldClock.day,
		"expires_day": WorldClock.day + 2,
		"accepted": false,
		"progress": 0,
		"completed": false,
		"claimed": false,
	}

func _assert_translated(text: String, what: String) -> void:
	assert_false(text.is_empty(), "%s is empty" % what)
	assert_null(_untranslated_word.search(text), "%s still shows untranslated text: %s" % [what, text])
