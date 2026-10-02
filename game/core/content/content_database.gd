class_name GameContentDatabase
extends Node

const DEFAULT_MANIFEST := preload("res://game/data/content_manifest.tres")

var manifest: ContentManifest = DEFAULT_MANIFEST
var _items: Dictionary = {}
var _crops: Dictionary = {}
var _npcs: Dictionary = {}
var _heart_events: Dictionary = {}
var _mail: Dictionary = {}
var _town_projects: Dictionary = {}
var _farm_expansions: Dictionary = {}
var _collection_milestones: Dictionary = {}
var _animals: Dictionary = {}
var _fish: Dictionary = {}
var _forage_entries: Dictionary = {}
var _food_buffs: Dictionary = {}
var _processing_recipes: Dictionary = {}
var _tool_upgrades: Dictionary = {}
var _placeables: Dictionary = {}
var _mining_nodes: Dictionary = {}
var _enemies: Dictionary = {}
var _quests: Dictionary = {}
var _shops: Dictionary = {}
var _recipes: Dictionary = {}
var _locations: Dictionary = {}
var _location_spawn_ids: Dictionary = {}
var _calendar_events: Dictionary = {}

func _ready() -> void:
	rebuild()

func rebuild() -> PackedStringArray:
	_items.clear()
	_crops.clear()
	_npcs.clear()
	_heart_events.clear()
	_mail.clear()
	_town_projects.clear()
	_farm_expansions.clear()
	_collection_milestones.clear()
	_animals.clear()
	_fish.clear()
	_forage_entries.clear()
	_food_buffs.clear()
	_processing_recipes.clear()
	_tool_upgrades.clear()
	_placeables.clear()
	_mining_nodes.clear()
	_enemies.clear()
	_quests.clear()
	_shops.clear()
	_recipes.clear()
	_locations.clear()
	_location_spawn_ids.clear()
	_calendar_events.clear()
	var errors := PackedStringArray()
	if manifest == null:
		errors.append("Content manifest is missing")
		return errors
	_index_resources(manifest.items, _items, "item", errors)
	_index_resources(manifest.crops, _crops, "crop", errors)
	_index_resources(manifest.npc_profiles, _npcs, "npc", errors)
	_index_resources(manifest.heart_events, _heart_events, "heart event", errors)
	_index_resources(manifest.mail, _mail, "mail", errors)
	_index_resources(manifest.town_projects, _town_projects, "town project", errors)
	_index_resources(manifest.farm_expansions, _farm_expansions, "farm expansion", errors)
	_index_resources(manifest.collection_milestones, _collection_milestones, "collection milestone", errors)
	_index_resources(manifest.farm_animals, _animals, "farm animal", errors)
	_index_resources(manifest.fish, _fish, "fish", errors)
	_index_resources(manifest.forage_entries, _forage_entries, "forage entry", errors)
	_index_resources(manifest.food_buffs, _food_buffs, "food buff", errors)
	_index_resources(manifest.processing_recipes, _processing_recipes, "processing recipe", errors)
	_index_resources(manifest.tool_upgrades, _tool_upgrades, "tool upgrade", errors)
	_index_resources(manifest.placeables, _placeables, "placeable", errors)
	_index_resources(manifest.mining_nodes, _mining_nodes, "mining node", errors)
	_index_resources(manifest.enemies, _enemies, "enemy", errors)
	_index_resources(manifest.quests, _quests, "quest", errors)
	_index_resources(manifest.shops, _shops, "shop", errors)
	_index_resources(manifest.recipes, _recipes, "recipe", errors)
	_index_resources(manifest.locations, _locations, "location", errors)
	_index_resources(manifest.calendar_events, _calendar_events, "calendar event", errors)
	_validate_references(errors)
	for message: String in errors:
		push_error("ContentDatabase: " + message)
	return errors

func get_item(id: StringName) -> ItemData:
	return _items.get(String(id)) as ItemData

func get_crop(id: StringName) -> CropData:
	return _crops.get(String(id)) as CropData

func get_npc(id: StringName) -> NpcProfileData:
	return _npcs.get(String(id)) as NpcProfileData

func get_heart_event(id: StringName) -> HeartEventData:
	return _heart_events.get(String(id)) as HeartEventData

func get_mail(id: StringName) -> MailData:
	return _mail.get(String(id)) as MailData

func get_town_project(id: StringName) -> TownProjectData:
	return _town_projects.get(String(id)) as TownProjectData

func get_farm_expansion(id: StringName) -> FarmExpansionData:
	return _farm_expansions.get(String(id)) as FarmExpansionData

func get_collection_milestone(id: StringName) -> CollectionMilestoneData:
	return _collection_milestones.get(String(id)) as CollectionMilestoneData

func get_farm_animal(id: StringName) -> FarmAnimalData:
	return _animals.get(String(id)) as FarmAnimalData

func get_fish(id: StringName) -> FishData:
	return _fish.get(String(id)) as FishData

func get_forage_entry(id: StringName) -> ForageEntryData:
	return _forage_entries.get(String(id)) as ForageEntryData

func get_food_buff(id: StringName) -> FoodBuffData:
	return _food_buffs.get(String(id)) as FoodBuffData

func get_processing_recipe(id: StringName) -> ProcessingRecipeData:
	return _processing_recipes.get(String(id)) as ProcessingRecipeData

func get_tool_upgrade(id: StringName) -> ToolUpgradeData:
	return _tool_upgrades.get(String(id)) as ToolUpgradeData

func get_placeable(id: StringName) -> PlaceableData:
	return _placeables.get(String(id)) as PlaceableData

func get_mining_node(id: StringName) -> MiningNodeData:
	return _mining_nodes.get(String(id)) as MiningNodeData

func get_enemy(id: StringName) -> EnemyData:
	return _enemies.get(String(id)) as EnemyData

func get_quest(id: StringName) -> QuestData:
	return _quests.get(String(id)) as QuestData

func get_shop(id: StringName) -> ShopData:
	return _shops.get(String(id)) as ShopData

func get_recipe(id: StringName) -> RecipeData:
	return _recipes.get(String(id)) as RecipeData

func get_location(id: StringName) -> WorldLocationData:
	return _locations.get(String(id)) as WorldLocationData

func get_location_for_scene(scene_path: String) -> WorldLocationData:
	if scene_path.is_empty():
		return null
	for location: WorldLocationData in get_all_locations():
		if location != null and location.scene_path == scene_path:
			return location
	return null

func get_current_location(tree: SceneTree) -> WorldLocationData:
	if tree == null or tree.current_scene == null:
		return null
	return get_location_for_scene(tree.current_scene.scene_file_path)

func has_location_spawn(location_id: StringName, spawn_id: StringName) -> bool:
	if location_id == &"" or spawn_id == &"":
		return false
	var raw_counts: Variant = _location_spawn_ids.get(String(location_id), {})
	if not raw_counts is Dictionary:
		return false
	return int((raw_counts as Dictionary).get(String(spawn_id), 0)) == 1

func get_calendar_event(id: StringName) -> CalendarEventData:
	return _calendar_events.get(String(id)) as CalendarEventData

func has_item(id: StringName) -> bool:
	return _items.has(String(id))

func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for value: Variant in _sorted_values(_items):
		result.append(value as ItemData)
	return result

func get_all_crops() -> Array[CropData]:
	var result: Array[CropData] = []
	for value: Variant in _sorted_values(_crops):
		result.append(value as CropData)
	return result

func get_all_npcs() -> Array[NpcProfileData]:
	var result: Array[NpcProfileData] = []
	for value: Variant in _sorted_values(_npcs):
		result.append(value as NpcProfileData)
	return result

func get_all_heart_events() -> Array[HeartEventData]:
	var result: Array[HeartEventData] = []
	for value: Variant in _sorted_values(_heart_events):
		result.append(value as HeartEventData)
	return result

func get_all_mail() -> Array[MailData]:
	var result: Array[MailData] = []
	for value: Variant in _sorted_values(_mail):
		result.append(value as MailData)
	return result

func get_all_town_projects() -> Array[TownProjectData]:
	var result: Array[TownProjectData] = []
	for value: Variant in _sorted_values(_town_projects):
		result.append(value as TownProjectData)
	return result

func get_all_farm_expansions() -> Array[FarmExpansionData]:
	var result: Array[FarmExpansionData] = []
	for value: Variant in _sorted_values(_farm_expansions):
		result.append(value as FarmExpansionData)
	return result

func get_all_collection_milestones() -> Array[CollectionMilestoneData]:
	var result: Array[CollectionMilestoneData] = []
	for value: Variant in _sorted_values(_collection_milestones):
		result.append(value as CollectionMilestoneData)
	return result

func get_all_farm_animals() -> Array[FarmAnimalData]:
	var result: Array[FarmAnimalData] = []
	for value: Variant in _sorted_values(_animals):
		result.append(value as FarmAnimalData)
	return result

func get_all_fish() -> Array[FishData]:
	var result: Array[FishData] = []
	for value: Variant in _sorted_values(_fish):
		result.append(value as FishData)
	return result

func get_all_forage_entries() -> Array[ForageEntryData]:
	var result: Array[ForageEntryData] = []
	for value: Variant in _sorted_values(_forage_entries):
		result.append(value as ForageEntryData)
	return result

func get_all_food_buffs() -> Array[FoodBuffData]:
	var result: Array[FoodBuffData] = []
	for value: Variant in _sorted_values(_food_buffs):
		result.append(value as FoodBuffData)
	return result

func get_all_processing_recipes() -> Array[ProcessingRecipeData]:
	var result: Array[ProcessingRecipeData] = []
	for value: Variant in _sorted_values(_processing_recipes):
		result.append(value as ProcessingRecipeData)
	return result

func get_all_tool_upgrades() -> Array[ToolUpgradeData]:
	var result: Array[ToolUpgradeData] = []
	for value: Variant in _sorted_values(_tool_upgrades):
		result.append(value as ToolUpgradeData)
	return result

func get_all_placeables() -> Array[PlaceableData]:
	var result: Array[PlaceableData] = []
	for value: Variant in _sorted_values(_placeables):
		result.append(value as PlaceableData)
	return result

func get_all_mining_nodes() -> Array[MiningNodeData]:
	var result: Array[MiningNodeData] = []
	for value: Variant in _sorted_values(_mining_nodes):
		result.append(value as MiningNodeData)
	return result

func get_all_enemies() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for value: Variant in _sorted_values(_enemies):
		result.append(value as EnemyData)
	return result

func get_all_quests() -> Array[QuestData]:
	var result: Array[QuestData] = []
	for value: Variant in _sorted_values(_quests):
		result.append(value as QuestData)
	return result

func get_all_recipes() -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for value: Variant in _sorted_values(_recipes):
		result.append(value as RecipeData)
	return result

func get_all_locations() -> Array[WorldLocationData]:
	var result: Array[WorldLocationData] = []
	for value: Variant in _sorted_values(_locations):
		result.append(value as WorldLocationData)
	return result

func get_all_calendar_events() -> Array[CalendarEventData]:
	var result: Array[CalendarEventData] = []
	for value: Variant in _sorted_values(_calendar_events):
		result.append(value as CalendarEventData)
	return result

func _index_resources(resources: Array, target: Dictionary, kind: String, errors: PackedStringArray) -> void:
	for resource: Resource in resources:
		if resource == null:
			continue
		var raw_id: Variant = resource.get("id")
		var id := StringName(String(raw_id))
		if id == &"":
			errors.append("%s resource has an empty id: %s" % [kind, resource.resource_path])
			continue
		var key := String(id)
		if target.has(key):
			errors.append("duplicate %s id '%s'" % [kind, key])
			continue
		target[key] = resource

func _is_numeric_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _is_positive_int_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) > 0

func _is_nonnegative_int_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0

func _validate_references(errors: PackedStringArray) -> void:
	var valid_seasons := PackedStringArray()
	for season: String in GameClock.SEASON_NAMES:
		valid_seasons.append(season)
	var valid_skills: Array[StringName] = SkillManager.SKILL_IDS.duplicate()
	var valid_buff_stats: Array[StringName] = [&"move_speed", &"tool_energy", &"fishing_wait", &"fishing_window"]
	var valid_tool_actions: Array[StringName] = [&"hoe", &"water", &"pickaxe", &"attack", &"fish"]

	for raw: Variant in _items.values():
		var item := raw as ItemData
		if item == null:
			continue
		if item.kind == ItemData.Kind.TOOL:
			if item.tool_action == &"" or not valid_tool_actions.has(item.tool_action):
				errors.append("tool item '%s' has invalid tool action '%s'" % [item.id, item.tool_action])
			if item.max_stack != 1:
				errors.append("tool item '%s' must have max_stack 1" % item.id)
		elif item.tool_action != &"":
			errors.append("non-tool item '%s' unexpectedly defines tool action '%s'" % [item.id, item.tool_action])
		if item.kind == ItemData.Kind.SEED:
			if item.crop_id == &"" or not _crops.has(String(item.crop_id)):
				errors.append("seed item '%s' references unknown crop '%s'" % [item.id, item.crop_id])
		elif item.crop_id != &"":
			errors.append("non-seed item '%s' unexpectedly references crop '%s'" % [item.id, item.crop_id])
		if item.kind == ItemData.Kind.PLACEABLE:
			if item.placeable_id == &"" or not _placeables.has(String(item.placeable_id)):
				errors.append("placeable item '%s' references unknown placeable '%s'" % [item.id, item.placeable_id])
		elif item.placeable_id != &"":
			errors.append("non-placeable item '%s' unexpectedly references placeable '%s'" % [item.id, item.placeable_id])
		if item.food_buff_id != &"" and not _food_buffs.has(String(item.food_buff_id)):
			errors.append("food item '%s' references unknown buff '%s'" % [item.id, item.food_buff_id])

	for raw: Variant in _crops.values():
		var crop := raw as CropData
		if crop == null:
			continue
		if crop.harvest_item_id == &"" or not _items.has(String(crop.harvest_item_id)):
			errors.append("crop '%s' references unknown harvest item '%s'" % [crop.id, crop.harvest_item_id])
		else:
			var harvest_item := _items[String(crop.harvest_item_id)] as ItemData
			if harvest_item == null or harvest_item.kind != ItemData.Kind.CROP:
				errors.append("crop '%s' harvest item '%s' is not a CROP item" % [crop.id, crop.harvest_item_id])
		for season: String in crop.allowed_seasons:
			if not valid_seasons.has(season):
				errors.append("crop '%s' has unknown season '%s'" % [crop.id, season])

	for raw: Variant in _food_buffs.values():
		var buff := raw as FoodBuffData
		if buff == null:
			continue
		if buff.duration_minutes <= 0:
			errors.append("food buff '%s' has invalid duration" % buff.id)
		for raw_stat: Variant in buff.modifiers.keys():
			var stat := StringName(String(raw_stat))
			if not valid_buff_stats.has(stat):
				errors.append("food buff '%s' references unsupported stat '%s'" % [buff.id, stat])
			elif not _is_numeric_value(buff.modifiers[raw_stat]) or float(buff.modifiers[raw_stat]) <= 0.0:
				errors.append("food buff '%s' has non-positive or non-numeric multiplier for '%s'" % [buff.id, stat])

	for raw: Variant in _npcs.values():
		var profile := raw as NpcProfileData
		if profile == null:
			continue
		_validate_item_list(profile.loved_items, "npc '%s' loved_items" % profile.id, errors)
		_validate_item_list(profile.liked_items, "npc '%s' liked_items" % profile.id, errors)
		_validate_item_list(profile.disliked_items, "npc '%s' disliked_items" % profile.id, errors)
		for raw_threshold: Variant in profile.dialogue_titles_by_hearts.keys():
			if typeof(raw_threshold) != TYPE_INT:
				errors.append("npc '%s' dialogue threshold '%s' is not an integer" % [profile.id, raw_threshold])
				continue
			var threshold := int(raw_threshold)
			if threshold < 0 or threshold > RelationshipManager.MAX_HEARTS:
				errors.append("npc '%s' dialogue threshold %d is outside heart range" % [profile.id, threshold])
			var raw_title: Variant = profile.dialogue_titles_by_hearts[raw_threshold]
			if (not raw_title is String and not raw_title is StringName) or String(raw_title).is_empty():
				errors.append("npc '%s' dialogue threshold %d has an invalid title" % [profile.id, threshold])
		if not valid_seasons.has(profile.birthday_season):
			errors.append("npc '%s' has unknown birthday season '%s'" % [profile.id, profile.birthday_season])
		if profile.birthday_day < 1 or profile.birthday_day > GameClock.DAYS_PER_SEASON:
			errors.append("npc '%s' has invalid birthday day %d" % [profile.id, profile.birthday_day])
		for location_id: StringName in [profile.home_location_id, profile.default_location_id]:
			if location_id != &"" and not _locations.has(String(location_id)):
				errors.append("npc '%s' references unknown location '%s'" % [profile.id, location_id])
		for schedule_entry: NpcScheduleEntry in profile.schedule_entries:
			if schedule_entry == null:
				continue
			if schedule_entry.location_id != &"" and not _locations.has(String(schedule_entry.location_id)):
				errors.append("npc '%s' schedule references unknown location '%s'" % [profile.id, schedule_entry.location_id])
			for weekday: int in schedule_entry.days_of_week:
				if weekday < 0 or weekday > 6:
					errors.append("npc '%s' schedule has invalid weekday %d" % [profile.id, weekday])
			for season: String in schedule_entry.seasons:
				if not valid_seasons.has(season):
					errors.append("npc '%s' schedule has unknown season '%s'" % [profile.id, season])
			for weather_name: String in schedule_entry.allowed_weather:
				if not PackedStringArray(["Clear", "Rain", "Storm"]).has(weather_name):
					errors.append("npc '%s' schedule has unknown weather '%s'" % [profile.id, weather_name])

	for raw: Variant in _heart_events.values():
		var heart_event := raw as HeartEventData
		if heart_event == null:
			continue
		if heart_event.npc_id == &"" or not _npcs.has(String(heart_event.npc_id)):
			errors.append("heart event '%s' references unknown npc '%s'" % [heart_event.id, heart_event.npc_id])
		if heart_event.location_id != &"" and not _locations.has(String(heart_event.location_id)):
			errors.append("heart event '%s' references unknown location '%s'" % [heart_event.id, heart_event.location_id])
		if heart_event.dialogue_title.is_empty():
			errors.append("heart event '%s' has an empty dialogue title" % heart_event.id)
		if heart_event.required_hearts < 0 or heart_event.required_hearts > RelationshipManager.MAX_HEARTS:
			errors.append("heart event '%s' has invalid heart requirement %d" % [heart_event.id, heart_event.required_hearts])
		if heart_event.end_minute <= heart_event.start_minute:
			errors.append("heart event '%s' has an invalid time window" % heart_event.id)
		for season: String in heart_event.seasons:
			if not valid_seasons.has(season):
				errors.append("heart event '%s' has unknown season '%s'" % [heart_event.id, season])

	for raw: Variant in _mail.values():
		var mail := raw as MailData
		if mail == null:
			continue
		if mail.sender_npc_id != &"" and not _npcs.has(String(mail.sender_npc_id)):
			errors.append("mail '%s' references unknown sender npc '%s'" % [mail.id, mail.sender_npc_id])
		if mail.required_hearts > 0 and mail.sender_npc_id == &"":
			errors.append("mail '%s' requires hearts but has no sender npc" % mail.id)
		if mail.subject.is_empty() or mail.body.is_empty():
			errors.append("mail '%s' requires subject and body" % mail.id)
		if mail.available_from_day < 1:
			errors.append("mail '%s' has invalid available day %d" % [mail.id, mail.available_from_day])
		if mail.required_hearts < 0 or mail.required_hearts > RelationshipManager.MAX_HEARTS:
			errors.append("mail '%s' has invalid heart requirement %d" % [mail.id, mail.required_hearts])
		if mail.reward_money < 0:
			errors.append("mail '%s' has negative reward money" % mail.id)
		if mail.required_completed_quest_id != &"" and not _quests.has(String(mail.required_completed_quest_id)):
			errors.append("mail '%s' references unknown required quest '%s'" % [mail.id, mail.required_completed_quest_id])
		for raw_item_id: Variant in mail.reward_items.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("mail '%s' rewards unknown item '%s'" % [mail.id, raw_item_id])
			elif not _is_positive_int_value(mail.reward_items[raw_item_id]):
				errors.append("mail '%s' has invalid reward quantity for '%s'" % [mail.id, raw_item_id])

	for raw: Variant in _town_projects.values():
		var project := raw as TownProjectData
		if project == null:
			continue
		if project.location_id == &"" or not _locations.has(String(project.location_id)):
			errors.append("town project '%s' references unknown location '%s'" % [project.id, project.location_id])
		if project.requirements.is_empty():
			errors.append("town project '%s' has no material requirements" % project.id)
		if project.reward_money < 0:
			errors.append("town project '%s' has negative reward money" % project.id)
		for raw_item_id: Variant in project.requirements.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("town project '%s' requires unknown item '%s'" % [project.id, raw_item_id])
			elif not _is_positive_int_value(project.requirements[raw_item_id]):
				errors.append("town project '%s' has invalid requirement quantity for '%s'" % [project.id, raw_item_id])
		for raw_item_id: Variant in project.reward_items.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("town project '%s' rewards unknown item '%s'" % [project.id, raw_item_id])
			elif not _is_positive_int_value(project.reward_items[raw_item_id]):
				errors.append("town project '%s' has invalid reward quantity for '%s'" % [project.id, raw_item_id])
		for prerequisite_id: StringName in project.prerequisites:
			if prerequisite_id == project.id or not _town_projects.has(String(prerequisite_id)):
				errors.append("town project '%s' references invalid prerequisite '%s'" % [project.id, prerequisite_id])

	for raw: Variant in _farm_expansions.values():
		var expansion := raw as FarmExpansionData
		if expansion == null:
			continue
		if expansion.housing_id == &"":
			errors.append("farm expansion '%s' has no housing id" % expansion.id)
		if expansion.capacity_after <= 0:
			errors.append("farm expansion '%s' has invalid target capacity %d" % [expansion.id, expansion.capacity_after])
		if expansion.money_cost < 0:
			errors.append("farm expansion '%s' has negative money cost" % expansion.id)
		if not expansion.has_valid_cost():
			errors.append("farm expansion '%s' has no cost" % expansion.id)
		for raw_item_id: Variant in expansion.materials.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("farm expansion '%s' requires unknown item '%s'" % [expansion.id, raw_item_id])
			elif not _is_positive_int_value(expansion.materials[raw_item_id]):
				errors.append("farm expansion '%s' has invalid material quantity for '%s'" % [expansion.id, raw_item_id])
		for prerequisite_id: StringName in expansion.prerequisites:
			if prerequisite_id == expansion.id or not _farm_expansions.has(String(prerequisite_id)):
				errors.append("farm expansion '%s' references invalid prerequisite '%s'" % [expansion.id, prerequisite_id])

	for raw: Variant in _collection_milestones.values():
		var milestone := raw as CollectionMilestoneData
		if milestone == null:
			continue
		if milestone.category == &"" and milestone.prerequisites.is_empty():
			errors.append("collection milestone '%s' has no progress condition" % milestone.id)
		elif milestone.category != &"" and not CollectionService.CATEGORIES.has(milestone.category):
			errors.append("collection milestone '%s' references unknown category '%s'" % [milestone.id, milestone.category])
		if milestone.required_discovered < 0:
			errors.append("collection milestone '%s' has negative discovered requirement" % milestone.id)
		if milestone.reward_money < 0:
			errors.append("collection milestone '%s' has negative reward money" % milestone.id)
		for raw_item_id: Variant in milestone.reward_items.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("collection milestone '%s' rewards unknown item '%s'" % [milestone.id, raw_item_id])
			elif not _is_positive_int_value(milestone.reward_items[raw_item_id]):
				errors.append("collection milestone '%s' has invalid reward quantity for '%s'" % [milestone.id, raw_item_id])
		for prerequisite_id: StringName in milestone.prerequisites:
			if prerequisite_id == milestone.id or not _collection_milestones.has(String(prerequisite_id)):
				errors.append("collection milestone '%s' references invalid prerequisite '%s'" % [milestone.id, prerequisite_id])

	for raw: Variant in _animals.values():
		var animal := raw as FarmAnimalData
		if animal == null:
			continue
		if not animal.has_valid_animation_ranges():
			errors.append("farm animal '%s' has invalid animation ranges" % animal.id)
		if animal.frame_size.x <= 0 or animal.frame_size.y <= 0:
			errors.append("farm animal '%s' has invalid frame size" % animal.id)
		if animal.housing_type == &"":
			errors.append("farm animal '%s' has no housing type" % animal.id)
		if animal.purchase_price <= 0:
			errors.append("farm animal '%s' has invalid purchase price" % animal.id)
		if animal.product_item_id != &"":
			if not _items.has(String(animal.product_item_id)):
				errors.append("farm animal '%s' references unknown product '%s'" % [animal.id, animal.product_item_id])
			else:
				var product_item := _items[String(animal.product_item_id)] as ItemData
				if product_item == null or not product_item.has_tag("animal_product"):
					errors.append("farm animal '%s' product '%s' lacks animal_product tag" % [animal.id, animal.product_item_id])
		if animal.premium_product_item_id != &"":
			if not _items.has(String(animal.premium_product_item_id)):
				errors.append("farm animal '%s' references unknown premium product '%s'" % [animal.id, animal.premium_product_item_id])
			else:
				var premium_item := _items[String(animal.premium_product_item_id)] as ItemData
				if premium_item == null or not premium_item.has_tag("animal_product"):
					errors.append("farm animal '%s' premium product '%s' lacks animal_product tag" % [animal.id, animal.premium_product_item_id])
		if animal.feed_item_id != &"" and not _items.has(String(animal.feed_item_id)):
			errors.append("farm animal '%s' references unknown feed item '%s'" % [animal.id, animal.feed_item_id])

	for raw: Variant in _fish.values():
		var fish := raw as FishData
		if fish == null:
			continue
		if fish.item_id == &"" or not _items.has(String(fish.item_id)):
			errors.append("fish '%s' references unknown item '%s'" % [fish.id, fish.item_id])
		else:
			var fish_item := _items[String(fish.item_id)] as ItemData
			if fish_item == null or not fish_item.has_tag("fish"):
				errors.append("fish '%s' item '%s' lacks fish tag" % [fish.id, fish.item_id])
		if fish.start_minute == fish.end_minute:
			errors.append("fish '%s' has an empty time window" % fish.id)
		if fish.catch_weight <= 0.0:
			errors.append("fish '%s' has non-positive catch weight" % fish.id)
		if fish.difficulty <= 0:
			errors.append("fish '%s' has invalid difficulty" % fish.id)
		for location_id: StringName in fish.locations:
			if not _locations.has(String(location_id)):
				errors.append("fish '%s' references unknown location '%s'" % [fish.id, location_id])
		for season: String in fish.seasons:
			if not valid_seasons.has(season):
				errors.append("fish '%s' has unknown season '%s'" % [fish.id, season])
		for weather_name: String in fish.allowed_weather:
			if not PackedStringArray(["Clear", "Rain", "Storm"]).has(weather_name):
				errors.append("fish '%s' has unknown weather '%s'" % [fish.id, weather_name])

	for raw: Variant in _forage_entries.values():
		var forage := raw as ForageEntryData
		if forage == null:
			continue
		if forage.item_id == &"" or not _items.has(String(forage.item_id)):
			errors.append("forage entry '%s' references unknown item '%s'" % [forage.id, forage.item_id])
		for location_id: StringName in forage.locations:
			if not _locations.has(String(location_id)):
				errors.append("forage entry '%s' references unknown location '%s'" % [forage.id, location_id])
		for season: String in forage.seasons:
			if not valid_seasons.has(season):
				errors.append("forage entry '%s' has unknown season '%s'" % [forage.id, season])

	for raw: Variant in _processing_recipes.values():
		var processing := raw as ProcessingRecipeData
		if processing == null:
			continue
		if processing.inputs.is_empty():
			errors.append("processing recipe '%s' has no inputs" % processing.id)
		if processing.output_item_id == &"" or not _items.has(String(processing.output_item_id)):
			errors.append("processing recipe '%s' outputs unknown item '%s'" % [processing.id, processing.output_item_id])
		if processing.output_quantity <= 0:
			errors.append("processing recipe '%s' has invalid output quantity" % processing.id)
		if processing.process_minutes <= 0:
			errors.append("processing recipe '%s' has invalid process duration" % processing.id)
		for raw_item_id: Variant in processing.inputs.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("processing recipe '%s' requires unknown item '%s'" % [processing.id, raw_item_id])
			elif not _is_positive_int_value(processing.inputs[raw_item_id]):
				errors.append("processing recipe '%s' has invalid input quantity for '%s'" % [processing.id, raw_item_id])
		if processing.required_skill != &"" and not valid_skills.has(processing.required_skill):
			errors.append("processing recipe '%s' references unknown required skill '%s'" % [processing.id, processing.required_skill])
		if processing.required_level < 1 or processing.required_level > SkillManager.LEVEL_THRESHOLDS.size():
			errors.append("processing recipe '%s' has invalid required level %d" % [processing.id, processing.required_level])

	for raw: Variant in _tool_upgrades.values():
		var upgrade := raw as ToolUpgradeData
		if upgrade == null:
			continue
		var source := _items.get(String(upgrade.source_item_id)) as ItemData
		var result := _items.get(String(upgrade.result_item_id)) as ItemData
		for item_id: StringName in [upgrade.source_item_id, upgrade.result_item_id]:
			if item_id == &"" or not _items.has(String(item_id)):
				errors.append("tool upgrade '%s' references unknown tool '%s'" % [upgrade.id, item_id])
		if source != null and not source.is_tool():
			errors.append("tool upgrade '%s' source '%s' is not a usable tool" % [upgrade.id, upgrade.source_item_id])
		if result != null and not result.is_tool():
			errors.append("tool upgrade '%s' result '%s' is not a usable tool" % [upgrade.id, upgrade.result_item_id])
		if source != null and result != null and source.is_tool() and result.is_tool():
			if source.tool_action != result.tool_action:
				errors.append("tool upgrade '%s' changes tool action from '%s' to '%s'" % [upgrade.id, source.tool_action, result.tool_action])
			if result.tool_power <= source.tool_power:
				errors.append("tool upgrade '%s' result power %d does not exceed source power %d" % [upgrade.id, result.tool_power, source.tool_power])
		if upgrade.money_cost < 0:
			errors.append("tool upgrade '%s' has negative money cost" % upgrade.id)
		for raw_item_id: Variant in upgrade.materials.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("tool upgrade '%s' requires unknown item '%s'" % [upgrade.id, raw_item_id])
			elif not _is_positive_int_value(upgrade.materials[raw_item_id]):
				errors.append("tool upgrade '%s' has invalid material quantity for '%s'" % [upgrade.id, raw_item_id])
		if upgrade.required_skill != &"" and not valid_skills.has(upgrade.required_skill):
			errors.append("tool upgrade '%s' references unknown required skill '%s'" % [upgrade.id, upgrade.required_skill])
		if upgrade.required_level < 1 or upgrade.required_level > SkillManager.LEVEL_THRESHOLDS.size():
			errors.append("tool upgrade '%s' has invalid required level %d" % [upgrade.id, upgrade.required_level])

	for raw: Variant in _placeables.values():
		var placeable := raw as PlaceableData
		if placeable == null:
			continue
		if placeable.item_id == &"" or not _items.has(String(placeable.item_id)):
			errors.append("placeable '%s' references unknown item '%s'" % [placeable.id, placeable.item_id])
		else:
			var source_item := _items[String(placeable.item_id)] as ItemData
			if source_item == null or not source_item.is_placeable() or source_item.placeable_id != placeable.id:
				errors.append("placeable '%s' item '%s' is not a valid linked PLACEABLE item" % [placeable.id, placeable.item_id])
		if placeable.scene_path.is_empty() or not ResourceLoader.exists(placeable.scene_path):
			errors.append("placeable '%s' references missing scene '%s'" % [placeable.id, placeable.scene_path])
		else:
			var placeable_scene := load(placeable.scene_path) as PackedScene
			if placeable_scene == null:
				errors.append("placeable '%s' scene '%s' is not a PackedScene" % [placeable.id, placeable.scene_path])
			else:
				var placeable_root := placeable_scene.instantiate()
				if not placeable_root is PlacedStructure:
					errors.append("placeable '%s' scene '%s' root is not a PlacedStructure" % [placeable.id, placeable.scene_path])
				elif placeable_root is ProcessingStation:
					_validate_processing_station_recipe_ids(placeable_root as ProcessingStation, "placeable '%s' processing station" % placeable.id, errors)
				if placeable_root != null:
					placeable_root.free()
		for location_id: StringName in placeable.allowed_location_ids:
			if not _locations.has(String(location_id)):
				errors.append("placeable '%s' references unknown location '%s'" % [placeable.id, location_id])

	for raw: Variant in _mining_nodes.values():
		var mining := raw as MiningNodeData
		if mining == null:
			continue
		if mining.drop_item_id == &"" or not _items.has(String(mining.drop_item_id)):
			errors.append("mining node '%s' references unknown drop '%s'" % [mining.id, mining.drop_item_id])
		else:
			var mining_item := _items[String(mining.drop_item_id)] as ItemData
			if mining_item == null or not mining_item.has_tag("mining"):
				errors.append("mining node '%s' drop '%s' lacks mining tag" % [mining.id, mining.drop_item_id])

	for raw: Variant in _enemies.values():
		var enemy := raw as EnemyData
		if enemy == null:
			continue
		if not enemy.has_valid_animation_ranges():
			errors.append("enemy '%s' has invalid animation ranges" % enemy.id)
		if enemy.drop_item_id != &"" and not _items.has(String(enemy.drop_item_id)):
			errors.append("enemy '%s' references unknown drop '%s'" % [enemy.id, enemy.drop_item_id])

	for raw: Variant in _quests.values():
		var quest := raw as QuestData
		if quest == null:
			continue
		if quest.title.is_empty():
			errors.append("quest '%s' has an empty title" % quest.id)
		if quest.required_amount <= 0:
			errors.append("quest '%s' has invalid required amount %d" % [quest.id, quest.required_amount])
		if quest.reward_money < 0:
			errors.append("quest '%s' has negative reward money" % quest.id)
		match quest.objective_type:
			QuestData.ObjectiveType.COLLECT:
				if quest.target_id != &"" and not _items.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown item target '%s'" % [quest.id, quest.target_id])
			QuestData.ObjectiveType.TALK:
				if quest.target_id != &"" and not _npcs.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown npc target '%s'" % [quest.id, quest.target_id])
			QuestData.ObjectiveType.HARVEST:
				if quest.target_id != &"" and not _crops.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown crop target '%s'" % [quest.id, quest.target_id])
			QuestData.ObjectiveType.FISH:
				if quest.target_id != &"" and not _fish.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown fish target '%s'" % [quest.id, quest.target_id])
			QuestData.ObjectiveType.MINE:
				if quest.target_id != &"" and not _mining_nodes.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown mining target '%s'" % [quest.id, quest.target_id])
			QuestData.ObjectiveType.DEFEAT:
				if quest.target_id != &"" and not _enemies.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown enemy target '%s'" % [quest.id, quest.target_id])
			QuestData.ObjectiveType.PROCESS:
				if quest.target_id != &"" and not _processing_recipes.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown processing target '%s'" % [quest.id, quest.target_id])
			QuestData.ObjectiveType.UPGRADE:
				if quest.target_id != &"" and not _tool_upgrades.has(String(quest.target_id)):
					errors.append("quest '%s' references unknown upgrade target '%s'" % [quest.id, quest.target_id])
		for raw_item_id: Variant in quest.reward_items.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("quest '%s' rewards unknown item '%s'" % [quest.id, raw_item_id])
			elif not _is_positive_int_value(quest.reward_items[raw_item_id]):
				errors.append("quest '%s' has invalid reward quantity for '%s'" % [quest.id, raw_item_id])
		if quest.next_quest_id != &"" and not _quests.has(String(quest.next_quest_id)):
			errors.append("quest '%s' references unknown next quest '%s'" % [quest.id, quest.next_quest_id])

	for raw: Variant in _shops.values():
		var shop := raw as ShopData
		if shop == null:
			continue
		if shop.display_name.is_empty():
			errors.append("shop '%s' has an empty display name" % shop.id)
		for raw_item_id: Variant in shop.stock.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("shop '%s' stocks unknown item '%s'" % [shop.id, raw_item_id])
			elif not _is_positive_int_value(shop.stock[raw_item_id]):
				errors.append("shop '%s' has invalid price for '%s'" % [shop.id, raw_item_id])
		for raw_season: Variant in shop.seasonal_stock.keys():
			var season_name := String(raw_season)
			if not valid_seasons.has(season_name):
				errors.append("shop '%s' has unknown season '%s'" % [shop.id, season_name])
				continue
			var seasonal: Variant = shop.seasonal_stock[raw_season]
			if not seasonal is Dictionary:
				errors.append("shop '%s' seasonal stock '%s' is not a Dictionary" % [shop.id, season_name])
				continue
			for raw_item_id: Variant in seasonal.keys():
				if not _items.has(String(raw_item_id)):
					errors.append("shop '%s' stocks unknown seasonal item '%s'" % [shop.id, raw_item_id])
				elif not _is_positive_int_value((seasonal as Dictionary)[raw_item_id]):
					errors.append("shop '%s' has invalid seasonal price for '%s'" % [shop.id, raw_item_id])
		var seen_animals: Dictionary = {}
		for animal_id: StringName in shop.animal_stock:
			if not _animals.has(String(animal_id)):
				errors.append("shop '%s' stocks unknown animal '%s'" % [shop.id, animal_id])
			elif seen_animals.has(String(animal_id)):
				errors.append("shop '%s' repeats animal '%s'" % [shop.id, animal_id])
			else:
				seen_animals[String(animal_id)] = true

	for raw: Variant in _recipes.values():
		var recipe := raw as RecipeData
		if recipe == null:
			continue
		if recipe.display_name.is_empty():
			errors.append("recipe '%s' has an empty display name" % recipe.id)
		if not [RecipeData.Category.CRAFTING, RecipeData.Category.COOKING].has(recipe.category):
			errors.append("recipe '%s' has invalid category %d" % [recipe.id, recipe.category])
		if recipe.ingredients.is_empty():
			errors.append("recipe '%s' has no ingredients" % recipe.id)
		if not _items.has(String(recipe.output_item_id)):
			errors.append("recipe '%s' outputs unknown item '%s'" % [recipe.id, recipe.output_item_id])
		if recipe.output_quantity <= 0:
			errors.append("recipe '%s' has invalid output quantity %d" % [recipe.id, recipe.output_quantity])
		for raw_item_id: Variant in recipe.ingredients.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("recipe '%s' requires unknown item '%s'" % [recipe.id, raw_item_id])
			elif not _is_positive_int_value(recipe.ingredients[raw_item_id]):
				errors.append("recipe '%s' has invalid ingredient quantity for '%s'" % [recipe.id, raw_item_id])
		if recipe.required_skill != &"" and not valid_skills.has(recipe.required_skill):
			errors.append("recipe '%s' references unknown required skill '%s'" % [recipe.id, recipe.required_skill])
		if recipe.required_level < 1 or recipe.required_level > SkillManager.LEVEL_THRESHOLDS.size():
			errors.append("recipe '%s' has invalid required level %d" % [recipe.id, recipe.required_level])

	var scene_paths: Dictionary = {}
	var persistent_state_keys: Dictionary = {}
	for raw: Variant in _locations.values():
		var location := raw as WorldLocationData
		if location == null:
			continue
		if location.scene_path.is_empty() or not ResourceLoader.exists(location.scene_path):
			errors.append("location '%s' references missing scene '%s'" % [location.id, location.scene_path])
			continue
		var packed := load(location.scene_path) as PackedScene
		if packed == null:
			errors.append("location '%s' scene '%s' is not a PackedScene" % [location.id, location.scene_path])
			continue
		if scene_paths.has(location.scene_path):
			errors.append("locations '%s' and '%s' share scene path '%s'" % [scene_paths[location.scene_path], location.id, location.scene_path])
		else:
			scene_paths[location.scene_path] = String(location.id)
		var spawn_counts := _get_scene_spawn_counts(packed)
		_location_spawn_ids[String(location.id)] = spawn_counts.duplicate(true)
		var player_count := _get_scene_group_count(packed, &"player")
		if player_count != 1:
			errors.append("location '%s' scene must contain exactly one player node, found %d" % [location.id, player_count])
		for record: Dictionary in _get_scene_persistent_state_records(packed):
			var state_key := String(record.get("key", ""))
			var node_name := String(record.get("node_name", "Node"))
			var required := bool(record.get("required", false))
			if state_key.is_empty():
				if required:
					errors.append("location '%s' persistent node '%s' is missing its stable id" % [location.id, node_name])
				continue
			if persistent_state_keys.has(state_key):
				var previous: Dictionary = persistent_state_keys[state_key]
				errors.append("persistent state key '%s' is shared by location '%s' node '%s' and location '%s' node '%s'" % [state_key, previous.get("location_id", ""), previous.get("node_name", ""), location.id, node_name])
			else:
				persistent_state_keys[state_key] = {"location_id": String(location.id), "node_name": node_name}
		_validate_location_scene_references(location, packed, errors)
		for raw_spawn_id: Variant in spawn_counts.keys():
			var spawn_id := String(raw_spawn_id)
			if spawn_id.is_empty():
				errors.append("location '%s' scene has a spawn point with an empty id" % location.id)
			elif int(spawn_counts[raw_spawn_id]) > 1:
				errors.append("location '%s' scene has duplicate spawn id '%s'" % [location.id, spawn_id])
		if location.default_spawn_id == &"":
			errors.append("location '%s' has an empty default spawn id" % location.id)
		elif not spawn_counts.has(String(location.default_spawn_id)):
			errors.append("location '%s' default spawn '%s' is missing from scene '%s'" % [location.id, location.default_spawn_id, location.scene_path])
		for portal: Dictionary in _get_scene_portal_records(packed):
			_validate_portal_record(location, portal, errors)

	for raw: Variant in _calendar_events.values():
		var event := raw as CalendarEventData
		if event == null:
			continue
		if event.location_id != &"" and not _locations.has(String(event.location_id)):
			errors.append("calendar event '%s' references unknown location '%s'" % [event.id, event.location_id])
		if event.day_of_season < 0 or event.day_of_season > GameClock.DAYS_PER_SEASON:
			errors.append("calendar event '%s' has invalid day-of-season %d" % [event.id, event.day_of_season])
		if event.end_minute <= event.start_minute:
			errors.append("calendar event '%s' has an invalid time window" % event.id)
		if event.reward_money < 0:
			errors.append("calendar event '%s' has negative reward money" % event.id)
		for weekday: int in event.days_of_week:
			if weekday < 0 or weekday > 6:
				errors.append("calendar event '%s' has invalid weekday %d" % [event.id, weekday])
		for season: String in event.seasons:
			if not valid_seasons.has(season):
				errors.append("calendar event '%s' has unknown season '%s'" % [event.id, season])
		for raw_item_id: Variant in event.reward_items.keys():
			if not _items.has(String(raw_item_id)):
				errors.append("calendar event '%s' rewards unknown item '%s'" % [event.id, raw_item_id])
			elif not _is_positive_int_value(event.reward_items[raw_item_id]):
				errors.append("calendar event '%s' has invalid reward quantity for '%s'" % [event.id, raw_item_id])
		if event.reward_skill != &"":
			if not valid_skills.has(event.reward_skill):
				errors.append("calendar event '%s' references unknown reward skill '%s'" % [event.id, event.reward_skill])
			elif event.reward_skill_xp <= 0:
				errors.append("calendar event '%s' has a reward skill without XP" % event.id)

	_validate_dependency_graphs(errors)

func _validate_dependency_graphs(errors: PackedStringArray) -> void:
	var quest_graph: Dictionary = {}
	for raw: Variant in _quests.values():
		var quest := raw as QuestData
		if quest == null:
			continue
		var next_ids: Array[String] = []
		if quest.next_quest_id != &"":
			next_ids.append(String(quest.next_quest_id))
		quest_graph[String(quest.id)] = next_ids
	_append_dependency_cycle_errors(quest_graph, "quest", errors)
	for message: String in _collect_quest_reachability_errors(_quests, quest_graph):
		errors.append(message)

	var project_graph: Dictionary = {}
	for raw: Variant in _town_projects.values():
		var project := raw as TownProjectData
		if project == null:
			continue
		project_graph[String(project.id)] = _string_name_array_to_strings(project.prerequisites)
	_append_dependency_cycle_errors(project_graph, "town project", errors)

	var expansion_graph: Dictionary = {}
	for raw: Variant in _farm_expansions.values():
		var expansion := raw as FarmExpansionData
		if expansion == null:
			continue
		expansion_graph[String(expansion.id)] = _string_name_array_to_strings(expansion.prerequisites)
	_append_dependency_cycle_errors(expansion_graph, "farm expansion", errors)
	for message: String in _collect_expansion_progression_errors(_farm_expansions):
		errors.append(message)

	var milestone_graph: Dictionary = {}
	for raw: Variant in _collection_milestones.values():
		var milestone := raw as CollectionMilestoneData
		if milestone == null:
			continue
		milestone_graph[String(milestone.id)] = _string_name_array_to_strings(milestone.prerequisites)
	_append_dependency_cycle_errors(milestone_graph, "collection milestone", errors)

func _collect_quest_reachability_errors(quests: Dictionary, graph: Dictionary) -> Array[String]:
	var messages: Array[String] = []
	var quest_ids: Array[String] = []
	var entry_points: Array[String] = []
	for raw_id: Variant in quests.keys():
		quest_ids.append(String(raw_id))
	quest_ids.sort()
	for quest_id: String in quest_ids:
		var quest := quests.get(quest_id) as QuestData
		if quest == null:
			continue
		if quest.auto_start and not quest.entry_point:
			messages.append("quest '%s' auto-starts but is not marked as an entry point" % quest.id)
		if quest.entry_point:
			entry_points.append(quest_id)
	if not quest_ids.is_empty() and entry_points.is_empty():
		messages.append("quest graph has no entry points")
		return messages

	var reachable: Dictionary = {}
	var pending: Array[String] = entry_points.duplicate()
	while not pending.is_empty():
		var node: String = pending.pop_back()
		if reachable.has(node):
			continue
		reachable[node] = true
		var raw_neighbors: Variant = graph.get(node, [])
		if not raw_neighbors is Array:
			continue
		for raw_neighbor: Variant in raw_neighbors:
			var neighbor := String(raw_neighbor)
			if graph.has(neighbor) and not reachable.has(neighbor):
				pending.append(neighbor)
	for quest_id: String in quest_ids:
		if not reachable.has(quest_id):
			messages.append("quest '%s' is unreachable from any entry point" % quest_id)
	return messages

func _string_name_array_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result

func _collect_expansion_progression_errors(expansions: Dictionary) -> Array[String]:
	var messages: Array[String] = []
	var capacities_by_housing: Dictionary = {}
	var ids: Array[String] = []
	for raw_id: Variant in expansions.keys():
		ids.append(String(raw_id))
	ids.sort()
	for expansion_id: String in ids:
		var expansion := expansions.get(expansion_id) as FarmExpansionData
		if expansion == null:
			continue
		var housing_key := String(expansion.housing_id)
		if not capacities_by_housing.has(housing_key):
			capacities_by_housing[housing_key] = {}
		var capacities: Dictionary = capacities_by_housing[housing_key]
		var capacity_key := str(expansion.capacity_after)
		if capacities.has(capacity_key):
			messages.append("farm expansions '%s' and '%s' share housing '%s' capacity %d" % [capacities[capacity_key], expansion.id, expansion.housing_id, expansion.capacity_after])
		else:
			capacities[capacity_key] = String(expansion.id)
		capacities_by_housing[housing_key] = capacities
		for prerequisite_id: StringName in expansion.prerequisites:
			var prerequisite := expansions.get(String(prerequisite_id)) as FarmExpansionData
			if prerequisite == null:
				continue
			if prerequisite.housing_id != expansion.housing_id:
				messages.append("farm expansion '%s' depends on '%s' from different housing '%s'" % [expansion.id, prerequisite.id, prerequisite.housing_id])
			elif prerequisite.capacity_after >= expansion.capacity_after:
				messages.append("farm expansion '%s' capacity %d does not exceed prerequisite '%s' capacity %d" % [expansion.id, expansion.capacity_after, prerequisite.id, prerequisite.capacity_after])
	return messages

func _append_dependency_cycle_errors(graph: Dictionary, kind: String, errors: PackedStringArray) -> void:
	for message: String in _collect_dependency_cycle_errors(graph, kind):
		errors.append(message)

func _collect_dependency_cycle_errors(graph: Dictionary, kind: String) -> Array[String]:
	var messages: Array[String] = []
	var state: Dictionary = {}
	var stack: Array[String] = []
	var reported: Dictionary = {}
	var nodes: Array[String] = []
	for raw_node: Variant in graph.keys():
		nodes.append(String(raw_node))
	nodes.sort()
	for node: String in nodes:
		if int(state.get(node, 0)) == 0:
			_visit_dependency_node(node, graph, state, stack, reported, kind, messages)
	return messages

func _visit_dependency_node(node: String, graph: Dictionary, state: Dictionary, stack: Array[String], reported: Dictionary, kind: String, messages: Array[String]) -> void:
	state[node] = 1
	stack.append(node)
	var neighbors: Array[String] = []
	var raw_neighbors: Variant = graph.get(node, [])
	if raw_neighbors is Array:
		for raw_neighbor: Variant in raw_neighbors:
			neighbors.append(String(raw_neighbor))
	neighbors.sort()
	for neighbor: String in neighbors:
		# Missing references are reported separately by the normal reference
		# validator; they cannot participate in a cycle inside this graph.
		if not graph.has(neighbor):
			continue
		var neighbor_state := int(state.get(neighbor, 0))
		if neighbor_state == 0:
			_visit_dependency_node(neighbor, graph, state, stack, reported, kind, messages)
		elif neighbor_state == 1:
			var start_index := stack.find(neighbor)
			if start_index < 0:
				continue
			var cycle_nodes: Array[String] = []
			for index in range(start_index, stack.size()):
				cycle_nodes.append(stack[index])
			var signature_nodes := cycle_nodes.duplicate()
			signature_nodes.sort()
			var signature := "|".join(PackedStringArray(signature_nodes))
			if reported.has(signature):
				continue
			reported[signature] = true
			var cycle_path := cycle_nodes.duplicate()
			cycle_path.append(neighbor)
			messages.append("%s dependency cycle: %s" % [kind, " -> ".join(PackedStringArray(cycle_path))])
	stack.pop_back()
	state[node] = 2

func _validate_item_list(item_ids: Array[StringName], context: String, errors: PackedStringArray) -> void:
	for item_id: StringName in item_ids:
		if not _items.has(String(item_id)):
			errors.append("%s references unknown item '%s'" % [context, item_id])

func _validate_processing_station_recipe_ids(station: ProcessingStation, context: String, errors: PackedStringArray) -> void:
	if station == null:
		return
	var seen_recipes: Dictionary = {}
	if station.recipe_ids.is_empty():
		errors.append("%s exposes no recipes" % context)
	for recipe_id: StringName in station.recipe_ids:
		if recipe_id == &"" or get_processing_recipe(recipe_id) == null:
			errors.append("%s references unknown recipe '%s'" % [context, recipe_id])
		elif seen_recipes.has(String(recipe_id)):
			errors.append("%s repeats recipe '%s'" % [context, recipe_id])
		else:
			seen_recipes[String(recipe_id)] = true

func _validate_location_scene_references(location: WorldLocationData, packed: PackedScene, errors: PackedStringArray) -> void:
	if location == null or packed == null:
		return
	var root := packed.instantiate()
	if root == null:
		return
	var housing_ids: Dictionary = {}
	_collect_scene_housing_ids(root, housing_ids)
	_validate_location_node_references(root, location, housing_ids, errors)
	root.free()

func _collect_scene_housing_ids(node: Node, housing_ids: Dictionary) -> void:
	if node is AnimalHousing:
		var housing := node as AnimalHousing
		if housing.housing_id != &"":
			housing_ids[String(housing.housing_id)] = true
	for child: Node in node.get_children():
		_collect_scene_housing_ids(child, housing_ids)

func _validate_location_node_references(node: Node, location: WorldLocationData, housing_ids: Dictionary, errors: PackedStringArray) -> void:
	var location_id := location.id
	if node is AnimalHousing:
		var housing := node as AnimalHousing
		if housing.location_id == &"" or housing.location_id != location_id:
			errors.append("location '%s' housing '%s' has mismatched location id '%s'" % [location_id, housing.housing_id, housing.location_id])
	elif node is AnimalFeedTrough:
		var trough := node as AnimalFeedTrough
		if trough.housing_id == &"" or not housing_ids.has(String(trough.housing_id)):
			errors.append("location '%s' feed trough '%s' references unknown housing '%s'" % [location_id, node.name, trough.housing_id])
		var feed_item := get_item(trough.feed_item_id)
		if trough.feed_item_id == &"" or feed_item == null or not feed_item.has_tag("animal_feed"):
			errors.append("location '%s' feed trough '%s' references invalid feed item '%s'" % [location_id, node.name, trough.feed_item_id])
	elif node is FarmField:
		var field := node as FarmField
		if field.location_id != &"" and field.location_id != location_id:
			errors.append("location '%s' farm field '%s' references different location '%s'" % [location_id, node.name, field.location_id])
	elif node is ForageSpawner:
		var spawner := node as ForageSpawner
		if spawner.location_id != &"" and spawner.location_id != location_id:
			errors.append("location '%s' forage spawner '%s' references different location '%s'" % [location_id, node.name, spawner.location_id])
	elif node is FishingSpot:
		var spot := node as FishingSpot
		if spot.location_id != &"" and spot.location_id != location_id:
			errors.append("location '%s' fishing spot '%s' references different location '%s'" % [location_id, node.name, spot.location_id])
		if spot.required_rod_id != &"":
			var rod := get_item(spot.required_rod_id)
			if rod == null or not rod.is_tool() or rod.tool_action != &"fish":
				errors.append("location '%s' fishing spot '%s' references invalid fishing rod '%s'" % [location_id, node.name, spot.required_rod_id])
	elif node is TownProjectBoard:
		var board := node as TownProjectBoard
		if board.location_id != &"" and board.location_id != location_id:
			errors.append("location '%s' town project board '%s' references different location '%s'" % [location_id, node.name, board.location_id])
	elif node is CalendarEventBooth:
		var booth := node as CalendarEventBooth
		var event := get_calendar_event(booth.event_id)
		if booth.event_id == &"" or event == null:
			errors.append("location '%s' event booth '%s' references unknown event '%s'" % [location_id, node.name, booth.event_id])
		elif event.location_id != &"" and event.location_id != location_id:
			errors.append("location '%s' event booth '%s' references event '%s' from location '%s'" % [location_id, node.name, event.id, event.location_id])
	elif node is ProcessingStation:
		_validate_processing_station_recipe_ids(node as ProcessingStation, "location '%s' processing station '%s'" % [location_id, node.name], errors)
	elif node is ShopStand:
		var stand := node as ShopStand
		var registered_shop := get_shop(stand.shop.id) if stand.shop != null and stand.shop.id != &"" else null
		if registered_shop == null or registered_shop != stand.shop:
			errors.append("location '%s' shop stand '%s' references an unregistered shop" % [location_id, node.name])
	for child: Node in node.get_children():
		_validate_location_node_references(child, location, housing_ids, errors)

func _get_scene_persistent_state_records(packed: PackedScene) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if packed == null:
		return records
	var root := packed.instantiate()
	if root == null:
		return records
	_collect_persistent_state_records(root, records)
	root.free()
	return records

func _collect_persistent_state_records(node: Node, records: Array[Dictionary]) -> void:
	if node is FarmField:
		var field := node as FarmField
		if field.field_id == &"":
			records.append({"key": "", "node_name": String(node.name), "required": true})
		else:
			var plot_count := maxi(field.columns, 1) * maxi(field.rows, 1)
			for index in range(1, plot_count + 1):
				records.append({"key": "farm:%s_%02d" % [String(field.field_id), index], "node_name": "%s/Plot%d" % [node.name, index], "required": true})
	elif node is FarmPlot:
		var plot := node as FarmPlot
		if plot.persistent_id != &"":
			records.append({"key": "farm:%s" % String(plot.persistent_id), "node_name": String(node.name), "required": false})
	elif node is FarmAnimal:
		var animal := node as FarmAnimal
		if animal.persistent_id != &"":
			records.append({"key": "animal:%s" % String(animal.persistent_id), "node_name": String(node.name), "required": false})
	elif node is MiningNode:
		var mining := node as MiningNode
		if mining.persistent_id != &"":
			records.append({"key": "mining:%s" % String(mining.persistent_id), "node_name": String(node.name), "required": false})
	elif node is HostileCreature:
		var enemy := node as HostileCreature
		if enemy.persistent_id != &"":
			records.append({"key": "enemy:%s" % String(enemy.persistent_id), "node_name": String(node.name), "required": false})
	elif node is WorldItemPickup:
		var pickup := node as WorldItemPickup
		if pickup.persistent_id != &"":
			records.append({"key": "pickup:%s" % String(pickup.persistent_id), "node_name": String(node.name), "required": false})
	elif node is ForageSpawner:
		var spawner := node as ForageSpawner
		records.append({"key": "forage:%s" % String(spawner.spawner_id) if spawner.spawner_id != &"" else "", "node_name": String(node.name), "required": true})
	elif node is StorageChest:
		var chest := node as StorageChest
		records.append({"key": "storage:%s" % String(chest.container_id) if chest.container_id != &"" else "", "node_name": String(node.name), "required": true})
	elif node is ProcessingStation:
		var station := node as ProcessingStation
		records.append({"key": "processing:%s" % String(station.station_id) if station.station_id != &"" else "", "node_name": String(node.name), "required": true})
	elif node is AnimalHousing:
		var housing := node as AnimalHousing
		records.append({"key": "housing:%s" % String(housing.housing_id) if housing.housing_id != &"" else "", "node_name": String(node.name), "required": true})
	for child: Node in node.get_children():
		_collect_persistent_state_records(child, records)

func _get_scene_group_count(packed: PackedScene, group: StringName) -> int:
	if packed == null or group == &"":
		return 0
	var root := packed.instantiate()
	if root == null:
		return 0
	var count := _count_group_nodes(root, group)
	root.free()
	return count

func _count_group_nodes(node: Node, group: StringName) -> int:
	var count := 1 if node.is_in_group(group) else 0
	for child: Node in node.get_children():
		count += _count_group_nodes(child, group)
	return count

func _get_scene_spawn_counts(packed: PackedScene) -> Dictionary:
	var counts: Dictionary = {}
	if packed == null:
		return counts
	var root := packed.instantiate()
	if root == null:
		return counts
	_collect_spawn_counts(root, counts)
	root.free()
	return counts

func _collect_spawn_counts(node: Node, counts: Dictionary) -> void:
	if node is WorldSpawnPoint:
		var spawn := node as WorldSpawnPoint
		var key := String(spawn.spawn_id)
		counts[key] = int(counts.get(key, 0)) + 1
	for child: Node in node.get_children():
		_collect_spawn_counts(child, counts)

func _get_scene_portal_records(packed: PackedScene) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if packed == null:
		return records
	var root := packed.instantiate()
	if root == null:
		return records
	_collect_portal_records(root, records)
	root.free()
	return records

func _collect_portal_records(node: Node, records: Array[Dictionary]) -> void:
	if node is ScenePortal:
		var portal := node as ScenePortal
		records.append({
			"node_name": String(portal.name),
			"target_location_id": String(portal.target_location_id),
			"target_scene": portal.target_scene,
			"target_spawn_id": String(portal.target_spawn_id),
		})
	for child: Node in node.get_children():
		_collect_portal_records(child, records)

func _validate_portal_record(source_location: WorldLocationData, portal: Dictionary, errors: PackedStringArray) -> void:
	var portal_name := String(portal.get("node_name", "Portal"))
	var target_location_id := StringName(String(portal.get("target_location_id", "")))
	var legacy_target_scene := String(portal.get("target_scene", ""))
	var target_spawn_id := StringName(String(portal.get("target_spawn_id", "")))
	if not legacy_target_scene.is_empty():
		errors.append("location '%s' portal '%s' still configures legacy target_scene '%s'" % [source_location.id, portal_name, legacy_target_scene])
	if target_location_id == &"":
		errors.append("location '%s' portal '%s' must use a stable target location id" % [source_location.id, portal_name])
		return
	var target_location := get_location(target_location_id)
	if target_location == null:
		errors.append("location '%s' portal '%s' references unknown target location '%s'" % [source_location.id, portal_name, target_location_id])
		return
	var target_packed := load(target_location.scene_path) as PackedScene
	if target_packed == null:
		errors.append("location '%s' portal '%s' target location '%s' has no valid PackedScene" % [source_location.id, portal_name, target_location_id])
		return
	var resolved_spawn := target_spawn_id if target_spawn_id != &"" else target_location.default_spawn_id
	var target_spawns := _get_scene_spawn_counts(target_packed)
	if resolved_spawn == &"" or not target_spawns.has(String(resolved_spawn)):
		errors.append("location '%s' portal '%s' target spawn '%s' is missing from location '%s'" % [source_location.id, portal_name, resolved_spawn, target_location_id])

func _sorted_values(source: Dictionary) -> Array:
	var keys: Array[String] = []
	for raw_key: Variant in source.keys():
		keys.append(String(raw_key))
	keys.sort()
	var result: Array = []
	for key: String in keys:
		result.append(source[key])
	return result
