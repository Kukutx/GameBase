extends SceneTree

const SMOKE_SAVE_DIRECTORY := "user://world_services_smoke"

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# The checks compare text with the English source strings.
	root.get_node("GameSettings").set("locale", "en")
	TranslationServer.set_locale("en")
	var inventory := root.get_node("InventoryState")
	var world_state := root.get_node("WorldState")
	var world_clock := root.get_node("WorldClock")
	var weather_state := root.get_node("WeatherState")
	var game_random := root.get_node("GameRandom")
	var player_state := root.get_node("PlayerState")
	var relationship_state := root.get_node("RelationshipState")
	var heart_events := root.get_node("HeartEvents")
	var mail_state := root.get_node("MailState")
	var quest_state := root.get_node("QuestState")
	var skills := root.get_node("Skills")
	var save_manager := root.get_node("SaveManager")
	var game_session := root.get_node("GameSession")
	var world_travel := root.get_node("WorldTravel")
	var shop_state := root.get_node("ShopState")
	var crafting_state := root.get_node("CraftingState")
	var building_state := root.get_node("BuildingState")
	var shipping_state := root.get_node("ShippingState")
	var event_state := root.get_node("EventState")
	var npc_memory := root.get_node("NpcMemory")
	var npc_context := root.get_node("NpcContext")
	var buff_state := root.get_node("BuffState")
	var animal_state := root.get_node("AnimalState")
	var town_projects := root.get_node("TownProjects")
	var mine_state := root.get_node("MineState")
	var content_db := root.get_node("ContentDB")
	var game_rules := root.get_node("GameRules")

	save_manager.save_directory = SMOKE_SAVE_DIRECTORY
	save_manager.select_slot(1)
	_cleanup_smoke_files()

	# New-game initialization must recompute Day 1 weather after resetting the
	# world seed, even when the previous session was already on Day 1.
	world_clock.call("set_time", 1, 8 * 60)
	game_random.call("set_seed", 93017)
	var default_day_one_weather := int(weather_state.call("get_weather_for_day", 1))
	var alternate_seed := -1
	for candidate_seed in range(1, 2048):
		game_random.call("set_seed", candidate_seed)
		if int(weather_state.get("current_weather")) != default_day_one_weather:
			alternate_seed = candidate_seed
			break
	_check(alternate_seed > 0, "Could not construct alternate Day 1 weather seed")

	var change_error := change_scene_to_file("res://game/world/dev_world.tscn")
	if change_error != OK:
		_fail("Could not open dev world")
		return
	await scene_changed
	await process_frame
	_check(int(game_random.get("world_seed")) == 93017, "New game did not restore the game's world seed")
	_check(int(weather_state.get("current_weather")) == int(weather_state.call("get_weather_for_day", 1)), "New game kept stale Day 1 weather from the previous seed")

	var player := get_first_node_in_group("player") as Node2D
	_check(player != null, "Player missing in dev world")
	_check(inventory.get_quantity(&"hoe") == 1, "Starter hoe missing")
	_check(inventory.get_quantity(&"watering_can") == 1, "Starter watering can missing")
	_check(inventory.get_quantity(&"pickaxe") == 1, "Starter pickaxe missing")
	_check(inventory.get_quantity(&"rusty_sword") == 1, "Starter sword missing")
	_check(inventory.get_quantity(&"fishing_rod") == 1, "Starter fishing rod missing")
	_check(inventory.get_quantity(&"turnip_seeds") == 10, "Starter seeds missing")
	_check(inventory.get_quantity(&"hay") == 20, "Starter hay missing")
	_check(player_state.energy == player_state.max_energy, "Starter energy incorrect")
	_check(player_state.health == player_state.max_health, "Starter health incorrect")
	_check(player_state.money == 500, "Starter money incorrect")
	_check(quest_state.is_active(&"meet_mira"), "Meet Mira quest did not start")
	_check(quest_state.is_active(&"gather_berries"), "Foraging quest did not start")
	var starter_forage := current_scene.get_node("DailyForage")
	_check(int(starter_forage.get_spawned_pickups().size()) == 3, "Starter daily forage did not spawn")

	# Farm animals use real daily production and persistent happiness state.
	var chicken := current_scene.get_node("Chicken")
	var cow := current_scene.get_node("Cow")
	_check(chicken.is_product_ready(), "Chicken should have a first-day egg")
	_check(cow.is_product_ready(), "Cow should have first-day milk")
	chicken.get_node("Interactable").interact(player)
	cow.get_node("Interactable").interact(player)
	_check(inventory.get_quantity(&"egg") == 1, "Egg collection failed")
	_check(inventory.get_quantity(&"milk") == 1, "Milk collection failed")
	_check(not chicken.is_product_ready() and not cow.is_product_ready(), "Animal product duplicated on same day")
	chicken.get_node("Interactable").interact(player)
	_check(int(chicken.happiness) == 55, "Petting chicken did not increase happiness")

	# Animal ownership uses Coop/Barn slots and the normal shop path. Fund the
	# purchase by exactly its price so downstream economy assertions stay stable.
	_check(animal_state.get_owned(&"starter_town").size() == 2, "Starter animal ownership migration incorrect")
	var chicken_price: int = int(content_db.get_entry(&"farm_animal", &"chicken").purchase_price)
	var money_before_animal_purchase: int = int(player_state.money)
	player_state.add_money(chicken_price)
	# Untyped: naming a module class here compiles it before the autoloads exist.
	var general_store: Resource = content_db.get_entry(&"shop", &"general_store")
	var chicken_offer: Resource = general_store.offers[0]
	var coop_before: Array[StringName] = []
	for record: Dictionary in animal_state.get_owned(&"starter_town", &"starter_coop"):
		coop_before.append(StringName(String(record.get("instance_id", ""))))
	var purchased_chicken: bool = shop_state.buy_offer(general_store, chicken_offer, {"location_id": &"starter_town"})
	await process_frame
	_check(purchased_chicken, "Animal shop purchase failed")
	var purchased_chicken_id := &""
	for record: Dictionary in animal_state.get_owned(&"starter_town", &"starter_coop"):
		if not coop_before.has(StringName(String(record.get("instance_id", "")))):
			purchased_chicken_id = StringName(String(record.get("instance_id", "")))
	_check(purchased_chicken_id != &"", "Purchased chicken has no instance id")
	_check(player_state.money == money_before_animal_purchase, "Animal purchase did not charge the correct price")
	_check(animal_state.get_owned(&"starter_town", &"starter_coop").size() == 2, "Purchased chicken was not assigned to Coop")
	_check(current_scene.get_node("CoopHousing").get_spawned_animals().size() == 2, "Purchased chicken did not spawn into the live scene")

	# Talk/social path without opening the dialogue balloon in headless mode.
	relationship_state.record_talk(&"mira")
	root.get_node("NpcSocialEvents").npc_talked.emit(&"mira")
	_check(quest_state.is_completed(&"meet_mira"), "Meet Mira quest did not complete")
	_check(relationship_state.get_points(&"mira") == 10, "Daily talk friendship missing")
	npc_memory.append_message(&"mira", &"player", "How is the garden today?")
	npc_memory.append_message(&"mira", &"npc", "The soil is ready for spring planting.")
	npc_memory.remember_fact(&"mira", &"player_started_farming", true)
	var context: Dictionary = npc_context.build_context(&"mira", player)
	_check(String(context["npc"]["role"]) == "Village gardener", "NPC context profile missing")
	_check((context["memory"]["recent_messages"] as Array).size() == 2, "NPC context memory missing")

	# Real pickup interaction drives inventory, quest and foraging skill.
	var berry_pickup := current_scene.get_node("BerryPickup")
	berry_pickup.get_node("Interactable").interact(player)
	await process_frame
	_check(inventory.get_quantity(&"berry") == 3, "Berry pickup failed")
	_check(quest_state.is_completed(&"gather_berries"), "Berry quest did not complete")
	_check(quest_state.is_active(&"first_harvest"), "First Harvest quest did not unlock")
	_check(skills.get_xp(&"foraging") == 30, "Foraging XP did not advance")
	var wood_pickup := current_scene.get_node("WoodPickup")
	wood_pickup.get_node("Interactable").interact(player)
	await process_frame
	_check(inventory.get_quantity(&"wood") == 5, "Starter wood pickup failed")

	# Gift path consumes one selected item and updates friendship/social skill.
	var mira := current_scene.get_node("Mira")
	var gift_delta: int = mira.receive_gift(&"berry")
	_check(gift_delta == 80, "Loved gift score incorrect")
	_check(inventory.get_quantity(&"berry") == 2, "Gift did not consume berry")
	_check(relationship_state.get_points(&"mira") == 90, "Friendship total incorrect")

	# Relationship stages and one-shot Heart Events are data-driven and visible to future AI context.
	relationship_state.add_friendship(&"mira", 410)
	_check(relationship_state.get_hearts(&"mira") == 2, "Mira did not reach two hearts")
	var pending_heart_event = heart_events.call("get_pending_event", &"mira")
	_check(pending_heart_event != null and String(pending_heart_event.id) == "mira_two_hearts", "Mira two-heart event did not become pending")
	var heart_context: Dictionary = npc_context.build_context(&"mira", player)
	_check(String(heart_context["relationship"]["pending_heart_event"]) == "mira_two_hearts", "AI context did not expose pending Heart Event")
	var consumed_heart_event = heart_events.call("consume_pending_event", &"mira")
	_check(consumed_heart_event != null and String(consumed_heart_event.id) == "mira_two_hearts", "Mira two-heart event could not be consumed")
	_check(heart_events.call("is_seen", &"mira_two_hearts"), "Heart Event seen flag was not persisted to WorldState")
	_check(bool(npc_memory.get_facts(&"mira").get("heart_event:mira_two_hearts", false)), "Heart Event was not recorded in NPC memory")
	heart_context = npc_context.build_context(&"mira", player)
	_check(String(heart_context["relationship"]["pending_heart_event"]).is_empty(), "Consumed Heart Event remained pending")
	_check((heart_context["relationship"]["seen_heart_events"] as Array).has("mira_two_hearts"), "AI context did not expose seen Heart Event")

	# Craft the remaining berries into food.
	_check(crafting_state.craft(&"field_snack"), "Crafting field snack failed")
	_check(inventory.get_quantity(&"berry") == 0, "Crafting did not consume berries")
	_check(inventory.get_quantity(&"field_snack") == 1, "Crafting output missing")

	# Economy path uses shared prices and inventory.
	var shop := load("res://game/data/shops/general_store.tres")
	_check(shop_state.buy(shop, &"turnip_seeds", 2) == 2, "Buying seeds failed")
	_check(player_state.money == 610, "Money after starter quests and seed purchase is incorrect")

	# Full farming cycle across three persistent plots.
	var farm_field := current_scene.get_node("FarmField")
	var plots: Array = farm_field.get_all_plots()
	_check(plots.size() == 3, "Starter farm did not generate three plots")
	for index in plots.size():
		var plot = plots[index]
		var plot_name := "Plot %d" % (index + 1)
		_check(plot.use_item(&"hoe"), "%s could not be tilled" % plot_name)
		_check(plot.use_item(&"turnip_seeds"), "%s could not be planted" % plot_name)
		if not plot.watered:
			_check(plot.use_item(&"watering_can"), "%s could not be watered" % plot_name)

	for day in range(2, 6):
		world_clock.set_time(day, 6 * 60)
		var hay_before_feed: int = inventory.get_quantity(&"hay")
		current_scene.get_node("CoopFeedTrough").get_node("Interactable").interact(player)
		current_scene.get_node("BarnFeedTrough").get_node("Interactable").interact(player)
		_check(inventory.get_quantity(&"hay") == hay_before_feed - 3, "Daily animal feeding did not consume one Hay per animal")
		_check(animal_state.get_unfed_count(&"starter_coop") == 0 and animal_state.get_unfed_count(&"starter_barn") == 0, "Daily animal feeding left animals unfed")
		if day < 5:
			for plot in plots:
				if not plot.watered:
					_check(plot.use_item(&"watering_can"), "Plot could not be watered for next day")
	_check(inventory.get_quantity(&"hay") == 8, "Hay balance after four feeding days is incorrect")

	for plot in plots:
		_check(plot.can_harvest(), "Crop did not mature after four watered days")
		plot.interact(player)
	_check(inventory.get_quantity(&"turnip") == 3, "Harvest output incorrect")
	_check(quest_state.is_completed(&"first_harvest"), "First Harvest quest did not complete")
	_check(skills.get_xp(&"farming") == 75, "Farming XP incorrect")

	_check(shop_state.sell(&"turnip", 1) == 1, "Selling harvest failed")
	_check(player_state.money == 895, "Money after harvest reward and sale incorrect")

	# Mailbox is world-reactive: day/quest conditions deliver letters and rewards are one-shot.
	_check(current_scene.get_node_or_null("Mailbox") != null, "Starter Town mailbox missing")
	_check(current_scene.get_node_or_null("WorldHud/MailboxMenu") != null, "Mailbox UI missing from WorldHud")
	mail_state.call("refresh_deliveries")
	_check(mail_state.call("is_received", &"mira_welcome"), "Mira welcome mail did not arrive by day two")
	var seeds_before_mail: int = inventory.get_quantity(&"turnip_seeds")
	_check(mail_state.call("claim_rewards", &"mira_welcome"), "Mira welcome mail reward could not be claimed")
	_check(inventory.get_quantity(&"turnip_seeds") == seeds_before_mail + 3, "Mira mail seed reward incorrect")
	_check(not mail_state.call("claim_rewards", &"mira_welcome"), "Mail reward could be claimed twice")
	_check(mail_state.call("is_read", &"mira_welcome") and mail_state.call("is_claimed", &"mira_welcome"), "Mail read/claimed state missing")

	# Shipping bin removes inventory now and pays only when the day advances.
	_check(current_scene.get_node_or_null("ShippingBin") != null, "Starter shipping bin missing")
	_check(shipping_state.ship_item(&"turnip", 1), "Shipping a turnip failed")
	_check(inventory.get_quantity(&"turnip") == 1, "Shipping did not remove the turnip")
	_check(shipping_state.get_pending_total() == 35, "Shipping pending value incorrect")
	_check(player_state.money == 895, "Shipping paid before overnight settlement")

	# Daily animal products become available again and are persisted at collection time.
	chicken = current_scene.get_node("Chicken")
	cow = current_scene.get_node("Cow")
	_check(chicken.is_product_ready() and cow.is_product_ready(), "Animal products did not refresh on later day")
	chicken.get_node("Interactable").interact(player)
	cow.get_node("Interactable").interact(player)
	_check(inventory.get_quantity(&"egg") == 2 and inventory.get_quantity(&"milk") == 2, "Second animal product collection failed")
	var saved_chicken_happiness := int(chicken.happiness)

	# Kitchen cooking produces real restorative food and a timed gameplay buff.
	inventory.add_item_by_id(&"turnip", 1)
	inventory.add_item_by_id(&"carrot", 1)
	inventory.add_item_by_id(&"potato", 1)
	_check(crafting_state.craft(&"vegetable_stew"), "Kitchen cooking recipe failed")
	_check(inventory.get_quantity(&"vegetable_stew") == 1, "Vegetable Stew output missing")
	player_state.energy = 40
	player_state.health = 60
	var food_controller := player.get_node("FarmToolController")
	food_controller.call("_consume_food", content_db.get_entry(&"item", &"vegetable_stew"))
	_check(inventory.get_quantity(&"vegetable_stew") == 0, "Cooked meal was not consumed")
	_check(player_state.energy == 85 and player_state.health == 80, "Cooked meal did not restore player stats")
	_check(buff_state.call("has_buff", &"hearty_worker"), "Cooked meal did not apply Hearty Worker buff")
	var saved_buff_remaining: int = int(buff_state.call("get_minutes_remaining", &"hearty_worker"))
	_check(saved_buff_remaining == 240, "Hearty Worker duration incorrect before save")

	# Save every global state, mutate it, and verify complete restoration.
	player.global_position = Vector2(31, 47)
	world_state.set_value(&"smoke:flag", true)
	var saved_money: int = player_state.money
	var saved_energy: int = player_state.energy
	var saved_relationship: int = relationship_state.get_points(&"mira")
	var saved_farming_xp: int = skills.get_xp(&"farming")
	var saved_shipping_total: int = shipping_state.get_pending_total()
	if not save_manager.save_game():
		_fail("SaveManager.save_game failed")
		return

	world_clock.set_time(1, 0)
	inventory.clear()
	world_state.clear()
	shipping_state.load_save_data({"pending": {}, "last_day_seen": 1})
	player_state.money = 0
	player_state.energy = 1
	relationship_state.clear()
	npc_memory.clear()
	quest_state.load_save_data({})
	skills.reset_new_game()
	buff_state.call("clear")
	player.global_position = Vector2.ZERO

	# Exercise the real Continue path: leave gameplay, then load from title.
	change_error = change_scene_to_file("res://game/ui/title_screen.tscn")
	_check(change_error == OK, "Could not return to title before Continue test")
	await scene_changed
	await process_frame
	# The title screen selects a slot on ready; the slot stays inside the smoke
	# save directory, so this test never reads or writes the user's real saves.
	_check(save_manager.save_path.begins_with(SMOKE_SAVE_DIRECTORY), "Title screen left the smoke save directory")
	var loaded: bool = await save_manager.load_game()
	_check(loaded, "SaveManager.load_game failed")
	player = get_first_node_in_group("player") as Node2D
	_check(world_clock.day == 5, "Clock did not restore")
	_check(inventory.get_quantity(&"turnip") == 1, "Inventory did not restore")
	_check(inventory.get_quantity(&"field_snack") == 1, "Crafted item did not restore")
	_check(shipping_state.get_pending_total() == saved_shipping_total, "Shipping state did not restore")
	_check(mail_state.call("is_claimed", &"mira_welcome"), "Mailbox claimed state did not restore through WorldState")
	_check(world_state.get_bool(&"smoke:flag"), "World state did not restore")
	_check(player_state.money == saved_money and player_state.energy == saved_energy, "Player state did not restore")
	_check(relationship_state.get_points(&"mira") == saved_relationship, "Relationship state did not restore")
	_check(bool(npc_memory.get_facts(&"mira").get("player_started_farming", false)), "NPC memory facts did not restore")
	_check(npc_memory.get_recent_messages(&"mira").size() == 2, "NPC conversation memory did not restore")
	_check(quest_state.is_completed(&"first_harvest"), "Quest state did not restore")
	_check(skills.get_xp(&"farming") == saved_farming_xp, "Skill state did not restore")
	_check(buff_state.call("has_buff", &"hearty_worker"), "Buff state did not restore")
	_check(int(buff_state.call("get_minutes_remaining", &"hearty_worker")) == saved_buff_remaining, "Buff remaining duration did not restore")
	_check(player != null and player.global_position.is_equal_approx(Vector2(31, 47)), "Player position did not restore")
	_check(inventory.get_quantity(&"egg") == 2 and inventory.get_quantity(&"milk") == 2, "Animal products did not restore")
	chicken = current_scene.get_node("Chicken")
	cow = current_scene.get_node("Cow")
	_check(not chicken.is_product_ready() and not cow.is_product_ready(), "Animal collection day did not persist")
	_check(int(chicken.happiness) == saved_chicken_happiness, "Animal happiness did not persist")
	_check(animal_state.get_owned(&"starter_town", &"starter_coop").size() == 2, "Purchased chicken ownership did not restore through WorldState")
	var restored_purchase_found := false
	for restored_record: Dictionary in animal_state.get_owned(&"starter_town", &"starter_coop"):
		if StringName(String(restored_record.get("instance_id", ""))) == purchased_chicken_id:
			restored_purchase_found = true
			break
	_check(restored_purchase_found, "Purchased chicken instance id did not survive Save/Continue")
	var restored_coop := current_scene.get_node("CoopHousing")
	await process_frame
	_check(restored_coop.get_spawned_animals().size() == 2, "Purchased chicken did not respawn after Continue")
	var restored_live_purchase := false
	for restored_animal in restored_coop.get_spawned_animals():
		if restored_animal != null and restored_animal.persistent_id == purchased_chicken_id:
			restored_live_purchase = true
			break
	_check(restored_live_purchase, "Purchased chicken live node did not preserve its persistent id")

	# World travel and sleep complete the daily loop.
	world_travel.travel_to(&"player_home", &"from_town")
	await world_travel.travel_finished
	player = get_first_node_in_group("player") as Node2D
	_check(current_scene.scene_file_path == "res://game/world/home_interior.tscn", "Travel to home failed")
	_check(player != null and player.global_position.is_equal_approx(Vector2(0, 72)), "Home spawn point failed")
	var bed := current_scene.get_node("Bed")
	var money_before_shipping_payout: int = player_state.money
	bed.get_node("Interactable").interact(player)
	await process_frame
	_check(world_clock.day == 6 and world_clock.minute_of_day == 6 * 60, "Sleeping did not advance to next morning")
	_check(player_state.energy == player_state.max_energy, "Sleeping did not restore energy")
	_check(not buff_state.call("has_buff", &"hearty_worker"), "Timed food buff did not expire overnight")
	_check(player_state.money == money_before_shipping_payout + saved_shipping_total, "Overnight shipping payout incorrect")
	_check(shipping_state.get_pending_total() == 0, "Shipping bin did not clear after payout")

	world_travel.travel_to(&"starter_town", &"from_home")
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(current_scene.scene_file_path == "res://game/world/dev_world.tscn", "Travel back to town failed")
	_check(player != null and player.global_position.is_equal_approx(Vector2(0, -120)), "Town spawn point failed")
	_check(current_scene.get_node_or_null("BerryPickup") == null, "Collected pickup respawned after scene travel")
	var restored_field := current_scene.get_node("FarmField")
	var restored_plot: Variant = restored_field.call("get_plot", Vector2i(0, 0))
	_check(restored_plot != null and restored_plot.tilled and restored_plot.crop_id == &"", "Persistent farm state did not survive scene travel")
	chicken = current_scene.get_node("Chicken")
	cow = current_scene.get_node("Cow")
	_check(not chicken.is_product_ready() and not cow.is_product_ready(), "Unfed animals incorrectly produced after sleeping")
	current_scene.get_node("CoopFeedTrough").get_node("Interactable").interact(player)
	current_scene.get_node("BarnFeedTrough").get_node("Interactable").interact(player)
	_check(inventory.get_quantity(&"hay") == 5, "Day-six feeding consumed the wrong amount of Hay")
	_check(chicken.is_product_ready() and cow.is_product_ready(), "Fed animals did not restore daily production")

	# Calendar events drive conditions, the HUD and high-priority NPC schedules.
	world_clock.set_time(6, 10 * 60)
	await process_frame
	_check(event_state.is_active(&"village_market"), "Village Market event did not activate")
	_check(game_rules.check("EVENT_ACTIVE village_market"), "EVENT_ACTIVE did not see the Village Market")
	var market_mira := current_scene.get_node("Mira")
	_check(market_mira.get_node("Schedule").current_activity == "Browse Village Market", "Event NPC schedule did not override normal route")
	_check("Village Market" in String(current_scene.get_node("WorldHud/Clock").text), "HUD did not show active event")

	# Three-town structure and cross-location NPC schedule.
	world_clock.set_time(7, 10 * 60)
	await process_frame
	_check(not event_state.is_active(&"village_market"), "Village Market did not end on Sunday")
	_check(not current_scene.get_node("Mira").visible, "Mira should leave Starter Town on Sunday")
	world_travel.travel_to(&"riverside_town", &"from_starter")
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(current_scene.scene_file_path == "res://game/world/riverside_town.tscn", "Travel to Riverside failed")
	_check(player != null and player.global_position.is_equal_approx(Vector2(-330, 0)), "Riverside spawn failed")
	_check(int(current_scene.get_node("DailyForage").get_spawned_pickups().size()) == 4, "Riverside daily forage did not spawn")
	var riverside_mira := current_scene.get_node("Mira")
	_check(riverside_mira.visible, "Mira did not appear in Riverside on Sunday")
	_check(riverside_mira.get_node("Schedule").current_activity == "Sunday visit to Riverside", "Cross-town NPC activity incorrect")
	var rowan := current_scene.get_node("Rowan")
	_check(rowan.visible and rowan.get_npc_id() == &"rowan", "Rowan profile-driven NPC missing in Riverside")
	_check(rowan.get_node("Schedule").current_activity == "Inspect the bridge", "Rowan profile schedule did not apply")
	# Rowan's lunch route must use NavigationAgent2D and cross the bridge rather than walk through the river collider.
	world_clock.set_time(7, 13 * 60)
	for _nav_frame in range(8):
		await physics_frame
	var rowan_agent := rowan.get_node("NavigationAgent2D")
	var rowan_path: PackedVector2Array = rowan_agent.get_current_navigation_path()
	_check(rowan_path.size() > 2, "Rowan did not receive a navigation path to the tavern")
	var rowan_uses_bridge := false
	for nav_point: Vector2 in rowan_path:
		if absf(nav_point.x) <= 36.0 and absf(nav_point.y) <= 28.0:
			rowan_uses_bridge = true
			break
	_check(rowan_uses_bridge, "Rowan navigation path bypassed Riverside bridge")
	world_clock.set_time(7, 10 * 60)
	await process_frame
	var fishing_state := root.get_node("FishingState")
	_check(fishing_state.start_cast(&"riverside_town", 0), "Could not start save-guard fishing probe")
	_check(save_manager.get_save_block_reason() == "Finish fishing before saving", "Active fishing did not block saving")
	_check(not save_manager.save_game(), "Save succeeded while fishing was active")
	fishing_state.cancel_cast(false)
	await process_frame
	_check(save_manager.get_save_block_reason().is_empty(), "Save remained blocked after fishing ended")
	var river_fish_before: int = int(inventory.get_quantity(&"river_trout")) + int(inventory.get_quantity(&"river_carp"))
	var fishing_xp_before: int = int(skills.get_xp(&"fishing"))
	current_scene.get_node("RiverFishingSpot").interact(player)
	var river_fish_after: int = int(inventory.get_quantity(&"river_trout")) + int(inventory.get_quantity(&"river_carp"))
	_check(river_fish_after == river_fish_before + 1, "Riverside fishing did not produce a river fish")
	_check(skills.get_xp(&"fishing") == fishing_xp_before + 20, "Fishing skill XP did not advance")
	_check(quest_state.is_completed(&"catch_first_fish"), "Fishing quest did not complete")
	_check(quest_state.is_active(&"mine_stone"), "Mining quest did not unlock")
	mail_state.call("refresh_deliveries")
	_check(mail_state.call("is_received", &"neri_first_catch"), "Neri first-catch mail did not unlock from quest completion")

	# Old Mine: resource nodes, combat, persistence, and daily respawn.
	world_travel.travel_to(&"old_mine", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(current_scene.scene_file_path == "res://game/world/old_mine.tscn", "Travel to Old Mine failed")
	_check(player != null and player.global_position.is_equal_approx(Vector2(-305, 0)), "Old Mine spawn failed")
	var stone_before: int = int(inventory.get_quantity(&"stone"))
	var copper_before: int = int(inventory.get_quantity(&"copper_ore"))
	var mining_xp_before: int = int(skills.get_xp(&"mining"))
	var stone_rock := current_scene.get_node("StoneRockA")
	var copper_rock := current_scene.get_node("CopperRock")
	_check(stone_rock.use_item(&"pickaxe"), "First stone hit failed")
	_check(stone_rock.use_item(&"pickaxe"), "Stone rock did not break")
	for _hit in range(3):
		_check(copper_rock.use_item(&"pickaxe"), "Copper vein hit failed")
	_check(inventory.get_quantity(&"stone") == stone_before + 2, "Stone mining drop incorrect")
	_check(inventory.get_quantity(&"copper_ore") == copper_before + 2, "Copper mining drop incorrect")
	_check(skills.get_xp(&"mining") == mining_xp_before + 48, "Mining XP incorrect")
	_check(quest_state.is_completed(&"mine_stone"), "Mining quest did not complete")
	_check(quest_state.is_active(&"defeat_green_slime"), "Combat quest did not unlock")

	var gel_before: int = int(inventory.get_quantity(&"slime_gel"))
	var combat_xp_before: int = int(skills.get_xp(&"combat"))
	var slime := current_scene.get_node("GreenSlime")
	_check(slime.take_damage(15), "First slime hit failed")
	_check(slime.take_damage(15), "Second slime hit failed")
	_check(slime.is_defeated, "Slime was not defeated")
	_check(inventory.get_quantity(&"slime_gel") == gel_before + 1, "Slime loot incorrect")
	_check(skills.get_xp(&"combat") == combat_xp_before + 20, "Combat XP incorrect")
	_check(quest_state.is_completed(&"defeat_green_slime"), "Combat quest did not complete")
	_check(quest_state.is_active(&"smelt_copper"), "Copper processing quest did not unlock")
	mail_state.call("refresh_deliveries")
	_check(mail_state.call("is_received", &"rowan_after_slime"), "Rowan post-slime mail did not unlock from quest completion")

	world_travel.travel_to(&"riverside_town", &"from_mine")
	await world_travel.travel_finished
	await process_frame
	_check(current_scene.scene_file_path == "res://game/world/riverside_town.tscn", "Return from Old Mine failed")
	world_travel.travel_to(&"old_mine", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	stone_rock = current_scene.get_node("StoneRockA")
	copper_rock = current_scene.get_node("CopperRock")
	slime = current_scene.get_node("GreenSlime")
	_check(stone_rock.is_depleted and copper_rock.is_depleted and slime.is_defeated, "Mine depletion did not persist on same day")
	world_clock.set_time(8, 10 * 60)
	await process_frame
	_check(not stone_rock.is_depleted and not copper_rock.is_depleted, "Mining nodes did not respawn next day")
	_check(not slime.is_defeated and slime.health == slime.data.max_health, "Slime did not respawn next day")
	for _hit in range(3):
		_check(copper_rock.use_item(&"pickaxe"), "Second-day copper vein hit failed")
	_check(inventory.get_quantity(&"copper_ore") == copper_before + 4, "Second-day copper mining drop incorrect")
	world_travel.travel_to(&"riverside_town", &"from_mine")
	await world_travel.travel_finished
	await process_frame

	# Mining feeds processing, which feeds real tool progression at Rowan's Forge.
	var furnace := current_scene.get_node("CopperFurnace")
	_check(furnace.start_recipe(&"smelt_copper_bar"), "Copper furnace could not start first bar")
	world_clock.set_time(int(world_clock.day), 11 * 60)
	await process_frame
	_check(furnace.output_ready and furnace.collect_output(), "First Copper Bar did not finish")
	_check(furnace.start_recipe(&"smelt_copper_bar"), "Copper furnace could not start second bar")
	world_clock.set_time(int(world_clock.day), 12 * 60)
	await process_frame
	_check(furnace.output_ready and furnace.collect_output(), "Second Copper Bar did not finish")
	_check(inventory.get_quantity(&"copper_bar") == 2, "Copper processing output incorrect")
	_check(quest_state.is_completed(&"smelt_copper"), "Copper processing quest did not complete")
	_check(quest_state.is_active(&"upgrade_pickaxe"), "Tool upgrade quest did not unlock")
	var upgrade_money_before: int = int(player_state.money)
	_check(root.get_node("UpgradeState").upgrade(&"copper_pickaxe_upgrade"), "Copper Pickaxe upgrade failed")
	_check(inventory.get_quantity(&"pickaxe") == 0 and inventory.get_quantity(&"copper_pickaxe") == 1, "Tool upgrade did not replace Pickaxe")
	_check(root.get_node("Hotbar").slots[2] == &"copper_pickaxe", "Tool upgrade did not update hotbar")
	_check(player_state.money == upgrade_money_before - 300 + 250, "Tool upgrade money/reward total incorrect")
	_check(quest_state.is_completed(&"upgrade_pickaxe"), "Tool upgrade quest did not complete")

	# Third copper cycle unlocks the first piece of farm automation.
	world_travel.travel_to(&"old_mine", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	world_clock.set_time(9, 10 * 60)
	await process_frame
	copper_rock = current_scene.get_node("CopperRock")
	_check(not copper_rock.is_depleted, "Copper vein did not respawn for automation progression")
	_check(copper_rock.use_item(&"copper_pickaxe"), "Copper Pickaxe first hit failed")
	_check(copper_rock.use_item(&"copper_pickaxe"), "Copper Pickaxe second hit failed")
	_check(copper_rock.is_depleted, "Copper Pickaxe did not break Copper Vein efficiently")
	world_travel.travel_to(&"riverside_town", &"from_mine")
	await world_travel.travel_finished
	await process_frame
	furnace = current_scene.get_node("CopperFurnace")
	_check(furnace.start_recipe(&"smelt_copper_bar"), "Copper furnace could not start automation bar")
	world_clock.set_time(9, 11 * 60)
	await process_frame
	_check(furnace.output_ready and furnace.collect_output(), "Automation Copper Bar did not finish")
	_check(crafting_state.craft(&"basic_sprinkler"), "Basic Sprinkler crafting failed")
	_check(inventory.get_quantity(&"basic_sprinkler") == 1, "Crafted Sprinkler missing")
	_check(root.get_node("Hotbar").slots.has(&"basic_sprinkler"), "Crafted Sprinkler was not assigned to an empty hotbar slot")

	world_travel.travel_to(&"starter_town", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(not building_state.can_place(&"basic_sprinkler", &"starter_town", Vector2(0, 0)), "Build Zone allowed a Sprinkler in town center")
	_check(building_state.can_place(&"basic_sprinkler", &"starter_town", Vector2(215, 96)), "Farm Build Zone rejected valid Sprinkler position")
	var sprinkler_record: Dictionary = building_state.place_from_inventory(&"basic_sprinkler", &"starter_town", Vector2(215, 96))
	_check(not sprinkler_record.is_empty(), "Sprinkler placement failed")
	_check(inventory.get_quantity(&"basic_sprinkler") == 0, "Sprinkler placement did not consume item")
	await process_frame
	_check(current_scene.get_node_or_null("PlacedStructures") != null, "Placed structure container missing")
	_check(building_state.is_point_affected(&"starter_town", &"water", Vector2(170, 70)), "Sprinkler does not cover west farm plot")
	_check(building_state.is_point_affected(&"starter_town", &"water", Vector2(260, 70)), "Sprinkler does not cover east farm plot")

	# Plant a crop, leave the farm unloaded for two days, then verify catch-up growth.
	var automation_field := current_scene.get_node("FarmField")
	var automation_plot = automation_field.call("get_plot", Vector2i(1, 0))
	_check(automation_plot != null, "Automation test plot missing")
	_check(automation_plot.use_item(&"turnip_seeds"), "Could not plant automation test crop")
	if not automation_plot.watered:
		_check(automation_plot.use_item(&"watering_can"), "Could not water automation test crop before leaving")
	var automation_start_growth: int = int(automation_plot.growth_days)
	world_travel.travel_to(&"player_home", &"from_town")
	await world_travel.travel_finished
	await process_frame
	world_clock.set_time(11, 6 * 60)
	await process_frame
	world_travel.travel_to(&"starter_town", &"from_home")
	await world_travel.travel_finished
	await process_frame
	automation_field = current_scene.get_node("FarmField")
	automation_plot = automation_field.call("get_plot", Vector2i(1, 0))
	_check(int(automation_plot.growth_days) == automation_start_growth + 2, "Unloaded farm did not catch up two sprinkler-watered days")
	_check(bool(automation_plot.watered), "Sprinkler did not leave returned farm watered")
	_check(current_scene.get_node("PlacedStructures").get_child_count() == 1, "Placed Sprinkler did not rebuild after scene travel")
	_check(building_state.remove_placement(&"starter_town", StringName(String(sprinkler_record["id"])), true), "Sprinkler removal failed")
	_check(inventory.get_quantity(&"basic_sprinkler") == 1, "Removing Sprinkler did not refund item")
	world_clock.set_time(11, 10 * 60)
	await process_frame

	world_travel.travel_to(&"riverside_town", &"from_starter")
	await world_travel.travel_finished
	await process_frame
	world_travel.travel_to(&"harbor_town", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(current_scene.scene_file_path == "res://game/world/harbor_town.tscn", "Travel to Harbor failed")
	_check(player != null and player.global_position.is_equal_approx(Vector2(-330, 0)), "Harbor spawn failed")
	_check(int(current_scene.get_node("DailyForage").get_spawned_pickups().size()) == 3, "Harbor daily forage did not spawn")
	var neri := current_scene.get_node("Neri")
	_check(neri.visible and neri.get_npc_id() == &"neri", "Neri profile-driven NPC missing in Harbor")
	_check(neri.get_node("Schedule").current_activity == "Trade at the harbor market", "Neri profile schedule did not apply")
	var ocean_fish_before: int = int(inventory.get_quantity(&"sardine")) + int(inventory.get_quantity(&"mackerel"))
	current_scene.get_node("HarborFishingSpot").interact(player)
	var ocean_fish_after: int = int(inventory.get_quantity(&"sardine")) + int(inventory.get_quantity(&"mackerel"))
	_check(ocean_fish_after == ocean_fish_before + 1, "Harbor fishing did not produce an ocean fish")
	_check(skills.get_xp(&"fishing") == fishing_xp_before + 40, "Second fishing catch did not add XP")

	# Weather is gameplay, not just HUD text: storm visuals, NPC shelter route, and rare fish pool.
	# A storm in a season the Storm Eel swims in.
	var storm_day: int = _find_weather_day_after("Storm", int(world_clock.day) + 1, PackedStringArray(["Spring", "Summer", "Autumn"]))
	_check(storm_day > int(world_clock.day), "Could not find a deterministic future storm day")
	world_clock.set_time(storm_day, 12 * 60)
	await process_frame
	_check(current_scene.get_node("WorldHud/WeatherOverlay").visible, "Outdoor storm overlay did not activate")
	_check(current_scene.get_node("Neri/Schedule").current_activity == "Secure the shed during the storm", "Storm NPC schedule did not override normal Harbor route")
	var storm_eel_available := false
	for fish in root.get_node("FishingState").get_available_fish(&"harbor_town"):
		if String(fish.id) == "storm_eel":
			storm_eel_available = true
			break
	_check(storm_eel_available, "Storm Eel did not enter Harbor fishing pool during storm")
	world_travel.travel_to(&"player_home", &"from_town")
	await world_travel.travel_finished
	await process_frame
	_check(not current_scene.get_node("WorldHud/WeatherOverlay").visible, "Indoor Home incorrectly rendered outdoor storm")
	world_travel.travel_to(&"harbor_town", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	_check(current_scene.get_node("WorldHud/WeatherOverlay").visible, "Storm overlay did not return after leaving Home")

	world_travel.travel_to(&"riverside_town", &"from_harbor")
	await world_travel.travel_finished
	await process_frame
	_check(current_scene.scene_file_path == "res://game/world/riverside_town.tscn", "Return from Harbor failed")
	world_travel.travel_to(&"starter_town", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(current_scene.scene_file_path == "res://game/world/dev_world.tscn", "Return to Starter Town failed")
	_check(player != null and player.global_position.is_equal_approx(Vector2(-340, 0)), "Starter Town road spawn failed")

	# Long-term Town Projects chain Farming, Mining, Animals and Fishing across all three towns.
	_check(current_scene.get_node_or_null("TownProjectBoard") != null, "Starter Town project board missing")
	_check(current_scene.get_node_or_null("WorldHud/TownProjectMenu") != null, "Town Project menu missing from WorldHud")
	inventory.add_item_by_id(&"turnip", 3)
	inventory.add_item_by_id(&"carrot", 3)
	inventory.add_item_by_id(&"potato", 3)
	inventory.add_item_by_id(&"wood", 10)
	var starter_tomato_seeds_before: int = inventory.get_quantity(&"tomato_seeds")
	var starter_project_money_before: int = player_state.money
	_check(town_projects.contribute_all_available(&"starter_garden_restoration") > 0, "Starter garden project accepted no materials")
	_check(town_projects.is_completed(&"starter_garden_restoration"), "Starter garden project did not complete")
	_check(game_rules.check("PROJECT_COMPLETED starter_garden_restoration"), "PROJECT_COMPLETED did not see the Starter project")
	_check(mail_state.is_received(&"mira_garden_restored"), "Starter project completion mail did not arrive immediately")
	_check(town_projects.claim_reward(&"starter_garden_restoration"), "Starter project reward could not be claimed")
	_check(inventory.get_quantity(&"tomato_seeds") == starter_tomato_seeds_before + 6, "Starter project seed reward incorrect")
	_check(player_state.money == starter_project_money_before + 600, "Starter project money reward incorrect")
	var project_context: Dictionary = npc_context.build_context(&"mira", player)
	var starter_project_seen := false
	for project_entry: Variant in project_context["town_projects"]:
		if project_entry is Dictionary and String(project_entry.get("id", "")) == "starter_garden_restoration":
			starter_project_seen = bool(project_entry.get("completed", false))
			break
	_check(starter_project_seen, "NPC AI context did not expose completed Starter project")

	world_travel.travel_to(&"riverside_town", &"from_starter")
	await world_travel.travel_finished
	await process_frame
	_check(current_scene.get_node_or_null("TownProjectBoard") != null, "Riverside project board missing")
	inventory.add_item_by_id(&"copper_bar", 3)
	inventory.add_item_by_id(&"stone", 12)
	inventory.add_item_by_id(&"wood", 15)
	var oil_maker_before: int = inventory.get_quantity(&"oil_maker")
	_check(town_projects.is_available(&"riverside_workshop_fund"), "Riverside project did not unlock")
	_check(town_projects.contribute_all_available(&"riverside_workshop_fund") > 0, "Riverside project accepted no materials")
	_check(town_projects.is_completed(&"riverside_workshop_fund"), "Riverside project did not complete")
	_check(game_rules.check("PROJECT_COMPLETED riverside_workshop_fund"), "PROJECT_COMPLETED did not see the Riverside project")
	_check(mail_state.is_received(&"rowan_workshop_expanded"), "Riverside project completion mail did not arrive immediately")
	_check(town_projects.claim_reward(&"riverside_workshop_fund"), "Riverside project reward could not be claimed")
	_check(inventory.get_quantity(&"oil_maker") == oil_maker_before + 1, "Riverside Oil Maker reward incorrect")

	world_travel.travel_to(&"harbor_town", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	_check(current_scene.get_node_or_null("TownProjectBoard") != null, "Harbor project board missing")
	inventory.add_item_by_id(&"sardine", 2)
	inventory.add_item_by_id(&"seaweed", 4)
	inventory.add_item_by_id(&"egg", 2)
	inventory.add_item_by_id(&"milk", 2)
	var fish_soup_before: int = inventory.get_quantity(&"fish_soup")
	_check(town_projects.is_available(&"harbor_supply_drive"), "Harbor project did not unlock")
	_check(town_projects.contribute_all_available(&"harbor_supply_drive") > 0, "Harbor project accepted no materials")
	_check(town_projects.is_completed(&"harbor_supply_drive"), "Harbor project did not complete")
	_check(game_rules.check("PROJECT_COMPLETED harbor_supply_drive"), "PROJECT_COMPLETED did not see the Harbor project")
	_check(mail_state.is_received(&"neri_harbor_restocked"), "Harbor project completion mail did not arrive immediately")
	_check(town_projects.claim_reward(&"harbor_supply_drive"), "Harbor project reward could not be claimed")
	_check(inventory.get_quantity(&"fish_soup") == fish_soup_before + 2, "Harbor project Fish Soup reward incorrect")

	# Seasonal festivals are real world interactions, not calendar-only labels. The
	# Harbor Derby pays once per game year and reopens on the same date next year.
	world_clock.set_time(70, 10 * 60)
	event_state.refresh(world_clock.day, world_clock.minute_of_day)
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	var derby_booth := current_scene.get_node_or_null("FallHarborDerbyBooth")
	_check(derby_booth != null and derby_booth.visible, "Fall Harbor Derby booth was not visible during the festival")
	for festival_npc_name: String in ["Mira", "Rowan", "Neri"]:
		var festival_npc := current_scene.get_node_or_null(festival_npc_name)
		_check(festival_npc != null and festival_npc.visible, "%s did not travel to Harbor for the Fall Derby" % festival_npc_name)
		if festival_npc != null:
			var festival_schedule := festival_npc.get_node_or_null("Schedule")
			_check(festival_schedule != null and String(festival_schedule.get("current_activity")) == "Watch the Harbor Derby", "%s did not switch to the Harbor Derby schedule" % festival_npc_name)
	var derby_money_before: int = int(player_state.money)
	var derby_soup_before: int = inventory.get_quantity(&"fish_soup")
	var derby_fishing_xp_before: int = skills.get_xp(&"fishing")
	derby_booth.get_node("Interactable").interact(player)
	await process_frame
	_check(event_state.has_claimed_participation(&"fall_harbor_derby"), "Fall Harbor Derby participation did not persist")
	_check(int(player_state.money) == derby_money_before + 400, "Fall Harbor Derby money reward incorrect")
	_check(inventory.get_quantity(&"fish_soup") == derby_soup_before + 2, "Fall Harbor Derby item reward incorrect")
	_check(skills.get_xp(&"fishing") == derby_fishing_xp_before + 150, "Fall Harbor Derby Fishing XP reward incorrect")
	derby_booth.get_node("Interactable").interact(player)
	await process_frame
	_check(int(player_state.money) == derby_money_before + 400, "Fall Harbor Derby could be claimed twice in one year")

	# When the event ends, visiting NPCs must immediately return to their normal
	# cross-town presence instead of remaining stranded in Harbor.
	world_clock.set_time(70, 19 * 60)
	event_state.refresh(world_clock.day, world_clock.minute_of_day)
	world_clock.advance_minutes(1)
	await process_frame
	var post_derby_mira := current_scene.get_node_or_null("Mira")
	var post_derby_rowan := current_scene.get_node_or_null("Rowan")
	var post_derby_neri := current_scene.get_node_or_null("Neri")
	_check(post_derby_mira != null and not post_derby_mira.visible, "Mira remained in Harbor after the Derby ended")
	_check(post_derby_rowan != null and not post_derby_rowan.visible, "Rowan remained in Harbor after the Derby ended")
	_check(post_derby_neri != null and post_derby_neri.visible, "Neri left her home town after the Derby ended")

	world_clock.set_time(182, 10 * 60)
	event_state.refresh(world_clock.day, world_clock.minute_of_day)
	await process_frame
	_check(event_state.get_year() == 2 and event_state.can_claim_participation(&"fall_harbor_derby"), "Fall Harbor Derby did not reopen in year two")
	derby_booth.get_node("Interactable").interact(player)
	await process_frame
	_check(int(player_state.money) == derby_money_before + 800, "Year-two Fall Harbor Derby reward incorrect")

	# Dynamic mine progression stays in one stable scene: clear Floor 1, descend
	# through Floor 6, verify Iron content, then exercise the 5-floor elevator checkpoint.
	world_travel.travel_to(&"riverside_town", &"from_harbor")
	await world_travel.travel_finished
	await process_frame
	world_travel.travel_to(&"old_mine", &"from_riverside")
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(mine_state.get_current_floor() == 1, "Mine surface entrance did not reset to Floor 1")
	_check(current_scene.get_node_or_null("StoneRockA") != null, "Mine Floor 1 static layout missing")
	for expected_floor in range(2, 7):
		var mine_floor := current_scene
		_clear_current_mine_floor(mine_floor)
		var mine_ladder := mine_floor.get_node("DeepLadder")
		_check(bool(mine_ladder.get("unlocked")), "Mine ladder did not unlock after clearing Floor %d" % (expected_floor - 1))
		mine_ladder.get_node("Interactable").interact(player)
		await world_travel.travel_finished
		await process_frame
		await process_frame
		player = get_first_node_in_group("player") as Node2D
		_check(current_scene.scene_file_path == "res://game/world/old_mine.tscn", "Mine floor transition changed the stable mine scene")
		_check(mine_state.get_current_floor() == expected_floor, "Mine ladder did not reach Floor %d" % expected_floor)
		_check(int(current_scene.get("current_floor")) == expected_floor, "Mine controller floor state desynced on Floor %d" % expected_floor)
		_check((current_scene.call("get_generated_rocks") as Array).size() > 0, "Generated rocks missing on Floor %d" % expected_floor)
		_check((current_scene.call("get_generated_enemies") as Array).size() > 0, "Generated enemies missing on Floor %d" % expected_floor)

	var floor_six_has_iron := false
	for mine_rock: Variant in current_scene.call("get_generated_rocks"):
		if mine_rock != null and mine_rock.data != null and mine_rock.data.id == &"iron_rock":
			floor_six_has_iron = true
			_check(String(mine_rock.persistent_id).begins_with("mine_f006_rock_"), "Floor 6 Iron Rock persistent ID is not floor-scoped")
			break
	_check(floor_six_has_iron, "Floor 6 did not guarantee an Iron Rock")
	_check(mine_state.get_deepest_floor() == 6, "Deepest mine floor did not persist")
	_check(mine_state.get_deepest_checkpoint() == 5, "Mine Floor 5 elevator checkpoint did not unlock")

	var mine_elevator := current_scene.get_node("MineElevator")
	mine_elevator.get_node("Interactable").interact(player)
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(mine_state.get_current_floor() == 1, "Deep-floor elevator did not return to Floor 1")
	mine_elevator = current_scene.get_node("MineElevator")
	_check(bool(mine_elevator.get_node("Interactable").enabled), "Surface elevator did not expose unlocked Floor 5 checkpoint")
	mine_elevator.get_node("Interactable").interact(player)
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(mine_state.get_current_floor() == 5, "Surface elevator did not jump to Floor 5")
	current_scene.get_node("MineElevator/Interactable").interact(player)
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(mine_state.get_current_floor() == 1, "Floor 5 elevator did not return to Floor 1")

	# Deep-tier runtime mapping remains in one stable scene while content changes
	# meaningfully at Floors 20, 40, 60, 90 and 120.
	mine_state.set_floor(20)
	world_travel.travel_to(&"old_mine", &"floor_entry")
	await world_travel.travel_finished
	await process_frame
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	var floor_twenty_has_gold := false
	for gold_candidate: Variant in current_scene.call("get_generated_rocks"):
		if gold_candidate != null and gold_candidate.data != null and gold_candidate.data.id == &"gold_rock":
			floor_twenty_has_gold = true
			_check(String(gold_candidate.persistent_id).begins_with("mine_f020_rock_"), "Floor 20 Gold Rock persistent ID is not floor-scoped")
			break
	_check(floor_twenty_has_gold, "Floor 20 did not guarantee a Gold Rock")
	for blue_enemy: Variant in current_scene.call("get_generated_enemies"):
		_check(blue_enemy != null and blue_enemy.data != null and blue_enemy.data.id == &"blue_slime", "Floor 20 generated a non-Blue Slime enemy")

	mine_state.set_floor(40)
	world_travel.travel_to(&"old_mine", &"floor_entry")
	await world_travel.travel_finished
	await process_frame
	await process_frame
	for red_enemy: Variant in current_scene.call("get_generated_enemies"):
		_check(red_enemy != null and red_enemy.data != null and red_enemy.data.id == &"red_slime", "Floor 40 generated a non-Red Slime enemy")

	mine_state.set_floor(60)
	world_travel.travel_to(&"old_mine", &"floor_entry")
	await world_travel.travel_finished
	await process_frame
	await process_frame
	var floor_sixty_has_iridium := false
	for iridium_candidate: Variant in current_scene.call("get_generated_rocks"):
		if iridium_candidate != null and iridium_candidate.data != null and iridium_candidate.data.id == &"iridium_rock":
			floor_sixty_has_iridium = true
			_check(String(iridium_candidate.persistent_id).begins_with("mine_f060_rock_"), "Floor 60 Iridium Rock persistent ID is not floor-scoped")
			break
	_check(floor_sixty_has_iridium, "Floor 60 did not guarantee an Iridium Rock")
	for shadow_enemy: Variant in current_scene.call("get_generated_enemies"):
		_check(shadow_enemy != null and shadow_enemy.data != null and shadow_enemy.data.id == &"shadow_slime", "Floor 60 generated a non-Shadow Slime enemy")

	mine_state.set_floor(90)
	world_travel.travel_to(&"old_mine", &"floor_entry")
	await world_travel.travel_finished
	await process_frame
	await process_frame
	for void_enemy: Variant in current_scene.call("get_generated_enemies"):
		_check(void_enemy != null and void_enemy.data != null and void_enemy.data.id == &"void_slime", "Floor 90 generated a non-Void Slime enemy")

	_check(quest_state.start_quest(&"reach_mine_bottom"), "Could not start mine-bottom runtime quest")
	mine_state.set_floor(120)
	_check(quest_state.is_completed(&"reach_mine_bottom"), "Mine-bottom quest did not complete at Floor 120")
	_check(mail_state.is_received(&"rowan_mine_bottom"), "Mine-bottom completion mail did not arrive immediately")
	world_travel.travel_to(&"old_mine", &"floor_entry")
	await world_travel.travel_finished
	await process_frame
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	for ancient_enemy: Variant in current_scene.call("get_generated_enemies"):
		_check(ancient_enemy != null and ancient_enemy.data != null and ancient_enemy.data.id == &"ancient_slime", "Floor 120 generated a non-Ancient Slime enemy")
	_check(not bool(current_scene.get_node("DeepLadder").get("unlocked")), "Floor 120 incorrectly exposed a deeper ladder")
	_check(mine_state.get_deepest_floor() == 120, "Deepest mine floor did not reach Floor 120")
	_check(mine_state.get_deepest_checkpoint() == 120, "Floor 120 elevator checkpoint was not retained")

	current_scene.get_node("MineElevator/Interactable").interact(player)
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(mine_state.get_current_floor() == 1, "Floor 120 elevator did not return to Floor 1")
	_check(bool(current_scene.get_node("MineElevator/Interactable").enabled), "Surface elevator did not expose the Floor 120 checkpoint")
	current_scene.get_node("MineElevator/Interactable").interact(player)
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(mine_state.get_current_floor() == 120, "Surface elevator did not return to the deepest Floor 120 checkpoint")
	current_scene.get_node("MineElevator/Interactable").interact(player)
	await world_travel.travel_finished
	await process_frame
	player = get_first_node_in_group("player") as Node2D
	_check(mine_state.get_current_floor() == 1, "Floor 120 elevator did not return to surface after checkpoint round-trip")

	# Defeat loop: zero HP wakes the player at home next morning with a money penalty.
	var collapse_day: int = int(world_clock.day)
	var money_before_collapse: int = int(player_state.money)
	var expected_loss: int = mini(maxi(int(ceil(float(money_before_collapse) * 0.10)), 1), money_before_collapse) if money_before_collapse > 0 else 0
	player_state.take_damage(player_state.max_health + 999)
	await root.get_node("GameSession").player_collapsed
	await process_frame
	_check(current_scene.scene_file_path == "res://game/world/home_interior.tscn", "Collapse did not return player home")
	_check(world_clock.day == collapse_day + 1 and world_clock.minute_of_day == 6 * 60, "Collapse did not advance to next morning")
	_check(player_state.health == player_state.max_health, "Collapse did not restore health")
	_check(player_state.energy == player_state.max_energy, "Collapse did not restore energy")
	_check(player_state.money == money_before_collapse - expected_loss, "Collapse money penalty incorrect")

	# Hard day boundary: staying awake until 02:00 forces rest at home with an
	# energy penalty instead of allowing infinite play through the night.
	player_state.set_energy(12)
	player_state.take_damage(20)
	var late_night_day: int = int(world_clock.day)
	world_clock.set_time(late_night_day, 1 * 60 + 59)
	world_clock.advance_minutes(1)
	await root.get_node("GameSession").late_night_collapse
	await process_frame
	_check(world_clock.day == late_night_day and world_clock.minute_of_day == 6 * 60, "02:00 late-night collapse did not wake at 06:00")
	_check(player_state.energy == maxi(player_state.max_energy / 2, 1), "Late-night collapse did not apply 50% energy penalty")
	_check(player_state.health == player_state.max_health, "Late-night collapse did not restore health")
	_check(current_scene.scene_file_path == "res://game/world/home_interior.tscn", "Late-night collapse did not keep player at home")
	_check(FileAccess.file_exists(root.get_node("SaveManager").save_path), "Late-night collapse did not autosave")

	if _failed:
		_cleanup_smoke_files()
		quit(1)
	else:
		_cleanup_smoke_files()
		print("LIFE_SIMULATION_SMOKE_OK")
		quit(0)

func _clear_current_mine_floor(mine: Node) -> void:
	if mine == null:
		return
	var floor := int(mine.get("current_floor"))
	var rocks: Array = mine.call("get_generated_rocks") if floor > 1 else []
	var enemies: Array = mine.call("get_generated_enemies") if floor > 1 else []
	if floor == 1:
		for node_name in ["StoneRockA", "StoneRockB", "CopperRock"]:
			var rock := mine.get_node_or_null(node_name)
			if rock != null:
				rocks.append(rock)
		var slime := mine.get_node_or_null("GreenSlime")
		if slime != null:
			enemies.append(slime)
	var current_day := int(root.get_node("WorldClock").day)
	for rock: Variant in rocks:
		if rock != null:
			rock.call("load_state_data", {"durability_left": 0, "depleted": true, "depleted_day": current_day})
	for enemy: Variant in enemies:
		if enemy != null:
			enemy.call("load_state_data", {"health": 0, "defeated": true, "defeated_day": current_day})
	mine.call("_refresh_ladder")

## The first day from `start_day` with `weather_name`, in one of `seasons` when
## any are given, or -1.
func _find_weather_day_after(weather_name: String, start_day: int, seasons := PackedStringArray()) -> int:
	var weather := root.get_node("WeatherState")
	# Loaded rather than named: this script compiles before the autoloads exist.
	var calendar: Resource = load("res://gamebase/core/time/game_calendar.gd").call("current")
	for day in range(maxi(start_day, 1), maxi(start_day, 1) + 730):
		if not seasons.is_empty() and not seasons.has(calendar.call("get_season_name", day)):
			continue
		if weather.get_weather_name(weather.get_weather_for_day(day)) == weather_name:
			return day
	return -1

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("LIFE_SIMULATION_SMOKE: " + message)

func _cleanup_smoke_files() -> void:
	for slot in range(1, 4):
		root.get_node("SaveManager").delete_slot(slot)
