class_name GameContentDatabase
extends ContentRegistry

## This game's content: every kind its modules define, indexed from the
## `ContentManifest`, with typed accessors and the checks between kinds.

const KIND_ITEM := &"item"
const KIND_CROP := &"crop"
const KIND_NPC := &"npc"
const KIND_HEART_EVENT := &"heart_event"
const KIND_MAIL := &"mail"
const KIND_TOWN_PROJECT := &"town_project"
const KIND_FARM_EXPANSION := &"farm_expansion"
const KIND_COLLECTION_MILESTONE := &"collection_milestone"
const KIND_FARM_ANIMAL := &"farm_animal"
const KIND_FISH := &"fish"
const KIND_FORAGE_ENTRY := &"forage_entry"
const KIND_FOOD_BUFF := &"food_buff"
const KIND_PROCESSING_RECIPE := &"processing_recipe"
const KIND_TOOL_UPGRADE := &"tool_upgrade"
const KIND_PLACEABLE := &"placeable"
const KIND_MINING_NODE := &"mining_node"
const KIND_ENEMY := &"enemy"
const KIND_QUEST := &"quest"
const KIND_SHOP := &"shop"
const KIND_RECIPE := &"recipe"
const KIND_CALENDAR_EVENT := &"calendar_event"

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
var _calendar_events: Dictionary = {}
var _audio_cues: Dictionary = {}
# Persistent state keys seen while validating location scenes in this rebuild.
var _persistent_state_keys: Dictionary = {}

func _index_content(errors: PackedStringArray) -> bool:
	_persistent_state_keys.clear()
	var source := manifest if manifest != null else ContentManifest.new()
	_items = register_entries(KIND_ITEM, source.items, "item", errors)
	_crops = register_entries(KIND_CROP, source.crops, "crop", errors)
	_npcs = register_entries(KIND_NPC, source.npc_profiles, "npc", errors)
	_heart_events = register_entries(KIND_HEART_EVENT, source.heart_events, "heart event", errors)
	_mail = register_entries(KIND_MAIL, source.mail, "mail", errors)
	_town_projects = register_entries(KIND_TOWN_PROJECT, source.town_projects, "town project", errors)
	_farm_expansions = register_entries(KIND_FARM_EXPANSION, source.farm_expansions, "farm expansion", errors)
	_collection_milestones = register_entries(KIND_COLLECTION_MILESTONE, source.collection_milestones, "collection milestone", errors)
	_animals = register_entries(KIND_FARM_ANIMAL, source.farm_animals, "farm animal", errors)
	_fish = register_entries(KIND_FISH, source.fish, "fish", errors)
	_forage_entries = register_entries(KIND_FORAGE_ENTRY, source.forage_entries, "forage entry", errors)
	_food_buffs = register_entries(KIND_FOOD_BUFF, source.food_buffs, "food buff", errors)
	_processing_recipes = register_entries(KIND_PROCESSING_RECIPE, source.processing_recipes, "processing recipe", errors)
	_tool_upgrades = register_entries(KIND_TOOL_UPGRADE, source.tool_upgrades, "tool upgrade", errors)
	_placeables = register_entries(KIND_PLACEABLE, source.placeables, "placeable", errors)
	_mining_nodes = register_entries(KIND_MINING_NODE, source.mining_nodes, "mining node", errors)
	_enemies = register_entries(KIND_ENEMY, source.enemies, "enemy", errors)
	_quests = register_entries(KIND_QUEST, source.quests, "quest", errors)
	_shops = register_entries(KIND_SHOP, source.shops, "shop", errors)
	_recipes = register_entries(KIND_RECIPE, source.recipes, "recipe", errors)
	_locations = register_entries(KIND_LOCATION, source.locations, "location", errors)
	_calendar_events = register_entries(KIND_CALENDAR_EVENT, source.calendar_events, "calendar event", errors)
	_audio_cues = register_entries(KIND_AUDIO_CUE, source.audio_cues, "audio cue", errors)
	register_entries(KIND_MINIGAME, source.minigames, "minigame", errors)
	if manifest == null:
		errors.append("Content manifest is missing")
		return false
	return true

func _validate_content(errors: PackedStringArray) -> void:
	_validate_references(errors)

func get_item(id: StringName) -> ItemData:
	return get_entry(KIND_ITEM, id) as ItemData

func get_crop(id: StringName) -> CropData:
	return get_entry(KIND_CROP, id) as CropData

func get_npc(id: StringName) -> NpcProfileData:
	return get_entry(KIND_NPC, id) as NpcProfileData

func get_heart_event(id: StringName) -> HeartEventData:
	return get_entry(KIND_HEART_EVENT, id) as HeartEventData

func get_mail(id: StringName) -> MailData:
	return get_entry(KIND_MAIL, id) as MailData

func get_town_project(id: StringName) -> TownProjectData:
	return get_entry(KIND_TOWN_PROJECT, id) as TownProjectData

func get_farm_expansion(id: StringName) -> FarmExpansionData:
	return get_entry(KIND_FARM_EXPANSION, id) as FarmExpansionData

func get_collection_milestone(id: StringName) -> CollectionMilestoneData:
	return get_entry(KIND_COLLECTION_MILESTONE, id) as CollectionMilestoneData

func get_farm_animal(id: StringName) -> FarmAnimalData:
	return get_entry(KIND_FARM_ANIMAL, id) as FarmAnimalData

func get_fish(id: StringName) -> FishData:
	return get_entry(KIND_FISH, id) as FishData

func get_forage_entry(id: StringName) -> ForageEntryData:
	return get_entry(KIND_FORAGE_ENTRY, id) as ForageEntryData

func get_food_buff(id: StringName) -> FoodBuffData:
	return get_entry(KIND_FOOD_BUFF, id) as FoodBuffData

func get_processing_recipe(id: StringName) -> ProcessingRecipeData:
	return get_entry(KIND_PROCESSING_RECIPE, id) as ProcessingRecipeData

func get_tool_upgrade(id: StringName) -> ToolUpgradeData:
	return get_entry(KIND_TOOL_UPGRADE, id) as ToolUpgradeData

func get_placeable(id: StringName) -> PlaceableData:
	return get_entry(KIND_PLACEABLE, id) as PlaceableData

func get_mining_node(id: StringName) -> MiningNodeData:
	return get_entry(KIND_MINING_NODE, id) as MiningNodeData

func get_enemy(id: StringName) -> EnemyData:
	return get_entry(KIND_ENEMY, id) as EnemyData

func get_quest(id: StringName) -> QuestData:
	return get_entry(KIND_QUEST, id) as QuestData

func get_shop(id: StringName) -> ShopData:
	return get_entry(KIND_SHOP, id) as ShopData

func get_recipe(id: StringName) -> RecipeData:
	return get_entry(KIND_RECIPE, id) as RecipeData

func get_calendar_event(id: StringName) -> CalendarEventData:
	return get_entry(KIND_CALENDAR_EVENT, id) as CalendarEventData

func has_item(id: StringName) -> bool:
	return has_entry(KIND_ITEM, id)

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

func get_all_calendar_events() -> Array[CalendarEventData]:
	var result: Array[CalendarEventData] = []
	for value: Variant in _sorted_values(_calendar_events):
		result.append(value as CalendarEventData)
	return result

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
	var valid_tool_actions: Array[StringName] = [ItemData.ACTION_TILL, ItemData.ACTION_WATER, ItemData.ACTION_MINE, ItemData.ACTION_FISH, MeleeController.TOOL_ACTION]

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
					var product_tags: Variant = product_item.tags if product_item != null else null
					errors.append("farm animal '%s' product '%s' lacks animal_product tag (tags=%s)" % [animal.id, animal.product_item_id, product_tags])
		if animal.premium_product_item_id != &"":
			if not _items.has(String(animal.premium_product_item_id)):
				errors.append("farm animal '%s' references unknown premium product '%s'" % [animal.id, animal.premium_product_item_id])
			else:
				var premium_item := _items[String(animal.premium_product_item_id)] as ItemData
				if premium_item == null or not premium_item.has_tag("animal_product"):
					var premium_tags: Variant = premium_item.tags if premium_item != null else null
					errors.append("farm animal '%s' premium product '%s' lacks animal_product tag (tags=%s)" % [animal.id, animal.premium_product_item_id, premium_tags])
		if animal.housing_type == &"":
			errors.append("farm animal '%s' has no housing type" % animal.id)
		var feed_item := _items.get(String(animal.feed_item_id)) as ItemData
		if feed_item == null or not feed_item.has_tag("animal_feed"):
			var feed_tags: Variant = feed_item.tags if feed_item != null else null
			errors.append("farm animal '%s' references invalid feed item '%s' (tags=%s)" % [animal.id, animal.feed_item_id, feed_tags])

	for raw: Variant in _fish.values():
		var fish := raw as FishData
		if fish == null:
			continue
		if fish.item_id == &"" or not _items.has(String(fish.item_id)):
			errors.append("fish '%s' references unknown item '%s'" % [fish.id, fish.item_id])
		else:
			var fish_item := _items[String(fish.item_id)] as ItemData
			if fish_item == null or not fish_item.has_tag("fish"):
				var fish_tags: Variant = fish_item.tags if fish_item != null else null
				errors.append("fish '%s' item '%s' lacks fish tag (tags=%s)" % [fish.id, fish.item_id, fish_tags])
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
				var mining_tags: Variant = mining_item.tags if mining_item != null else null
				errors.append("mining node '%s' drop '%s' lacks mining tag (tags=%s)" % [mining.id, mining.drop_item_id, mining_tags])

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
	for message: String in collect_dependency_cycle_errors(graph, kind):
		errors.append(message)

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

func _validate_location_scene(location: WorldLocationData, root: Node, errors: PackedStringArray) -> void:
	var records: Array[Dictionary] = []
	_collect_persistent_state_records(root, records)
	for record: Dictionary in records:
		var state_key := String(record.get("key", ""))
		var node_name := String(record.get("node_name", "Node"))
		var required := bool(record.get("required", false))
		if state_key.is_empty():
			if required:
				errors.append("location '%s' persistent node '%s' is missing its stable id" % [location.id, node_name])
			continue
		if _persistent_state_keys.has(state_key):
			var previous: Dictionary = _persistent_state_keys[state_key]
			errors.append("persistent state key '%s' is shared by location '%s' node '%s' and location '%s' node '%s'" % [state_key, previous.get("location_id", ""), previous.get("node_name", ""), location.id, node_name])
		else:
			_persistent_state_keys[state_key] = {"location_id": String(location.id), "node_name": node_name}
	var housing_ids: Dictionary = {}
	_collect_scene_housing_ids(root, housing_ids)
	_validate_location_node_references(root, location, housing_ids, errors)

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
		if housing.display_name.is_empty() or housing.housing_type == &"":
			errors.append("location '%s' housing '%s' needs a display name and a housing type" % [location_id, housing.housing_id])
	elif node is AnimalFeedTrough:
		var trough := node as AnimalFeedTrough
		if trough.housing_id == &"" or not housing_ids.has(String(trough.housing_id)):
			errors.append("location '%s' feed trough '%s' references unknown housing '%s'" % [location_id, node.name, trough.housing_id])
	elif node is MineFloorController:
		var mine := node as MineFloorController
		if mine.entrance_spawn_ids.is_empty():
			errors.append("location '%s' mine '%s' has no entrance spawn" % [location_id, node.name])
		var spawn_ids: Array[StringName] = mine.entrance_spawn_ids.duplicate()
		spawn_ids.append(mine.floor_spawn_id)
		for spawn_id: StringName in spawn_ids:
			if not has_location_spawn(location_id, spawn_id):
				errors.append("location '%s' mine '%s' names spawn '%s', which its scene does not have" % [location_id, node.name, spawn_id])
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
