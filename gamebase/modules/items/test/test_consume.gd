extends GutTest

## Eating and drinking (`InventoryStore.consume`): what an item restores, the
## buff it gives and what the player is told.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _buff_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_buff_snapshot = BuffState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	var steady := FoodBuffData.new()
	steady.id = &"fixture_steady"
	steady.display_name = "Steady"
	steady.duration_minutes = 60
	steady.multipliers[&"fixture_speed"] = 1.1
	ContentFixture.use(self, [
		_edible(&"fixture_bread", "Bread", ItemData.Kind.FOOD, {&"fixture_energy": 20}, &""),
		_edible(&"fixture_tonic", "Tonic", ItemData.Kind.POTION, {&"fixture_hp": 15, &"fixture_energy": 5}, steady.id),
		steady,
		ContentFixture.vital(&"fixture_energy"),
		ContentFixture.vital(&"fixture_hp"),
	])
	InventoryState.clear()
	Vitals.reset_new_game()
	BuffState.clear()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	BuffState.load_save_data(_buff_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_food_restores_and_is_eaten() -> void:
	InventoryState.add_item_by_id(&"fixture_bread", 1)
	Vitals.set_value(&"fixture_energy", 70)
	watch_signals(GameEvents)
	assert_true(InventoryState.consume(ItemData.find(&"fixture_bread")))
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Ate Bread (+20 Energy)"])
	assert_eq(Vitals.get_value(&"fixture_energy"), 90)
	assert_eq(InventoryState.get_quantity(&"fixture_bread"), 0)

func test_a_potion_is_drunk_and_gives_its_buff() -> void:
	InventoryState.add_item_by_id(&"fixture_tonic", 1)
	Vitals.set_value(&"fixture_hp", 80)
	watch_signals(GameEvents)
	assert_true(InventoryState.consume(ItemData.find(&"fixture_tonic")))
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Drank Tonic (+15 Hp)"])
	assert_eq(Vitals.get_value(&"fixture_hp"), 95)
	assert_true(BuffState.has_buff(&"fixture_steady"))

func test_what_would_do_nothing_is_not_used_up() -> void:
	InventoryState.add_item_by_id(&"fixture_bread", 1)
	watch_signals(GameEvents)
	assert_false(InventoryState.consume(ItemData.find(&"fixture_bread")))
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["You do not need that right now"])
	assert_eq(InventoryState.get_quantity(&"fixture_bread"), 1)

func test_an_item_the_player_does_not_hold_is_not_eaten() -> void:
	Vitals.set_value(&"fixture_energy", 10)
	watch_signals(GameEvents)
	assert_false(InventoryState.consume(ItemData.find(&"fixture_bread")))
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["No Bread available"])
	assert_eq(Vitals.get_value(&"fixture_energy"), 10)

func test_an_item_restores_only_vitals_the_game_has() -> void:
	var registry := ContentRegistry.active
	var odd := _edible(&"fixture_odd", "Odd", ItemData.Kind.FOOD, {&"fixture_mana": 5, &"fixture_hp": 0}, &"")
	assert_eq(odd.find_problems(registry), PackedStringArray(["restores unknown vital 'fixture_mana'", "restores no fixture_hp"]))

static func _edible(id: StringName, display_name: String, kind: ItemData.Kind, restores: Dictionary, buff_id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.kind = kind
	item.restores.assign(restores)
	item.food_buff_id = buff_id
	return item
