extends GutTest

## The player's melee attack (`MeleeAttack`): which item swings, what a swing
## costs and what it hits.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

## A body that takes damage, as `HostileCreature` does.
class Target extends StaticBody2D:
	var taken := 0

	func take_damage(amount: int) -> bool:
		taken += amount
		return true

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _buff_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_buff_snapshot = BuffState.to_save_data()
	ContentFixture.use(self, [_tool(&"fixture_sword", "Sword", MeleeAttack.TOOL_ACTION, 7), _tool(&"fixture_hoe", "Hoe", &"fixture_till", 1)])
	InventoryState.clear()
	PlayerState.reset_new_game()
	BuffState.clear()
	InventoryState.add_item_by_id(&"fixture_sword", 1)
	InventoryState.add_item_by_id(&"fixture_hoe", 1)
	Hotbar.set_slot_item(0, &"fixture_sword")
	Hotbar.set_slot_item(1, &"fixture_hoe")
	Hotbar.select_slot(0)

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	BuffState.load_save_data(_buff_snapshot)

func test_a_swing_hits_what_is_in_reach_for_the_weapon_s_power() -> void:
	var attack := _attack()
	var target := Target.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	target.add_child(shape)
	add_child_autofree(target)
	await get_tree().physics_frame
	await get_tree().physics_frame
	PlayerState.energy = 50
	assert_true(attack.attack_selected_weapon())
	assert_eq(target.taken, 7)
	assert_eq(PlayerState.energy, 50 - attack.get_energy_cost())

func test_a_swing_at_nothing_still_costs_energy() -> void:
	var attack := _attack()
	PlayerState.energy = 50
	watch_signals(GameEvents)
	assert_true(attack.attack_selected_weapon())
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Swung Sword"])
	assert_eq(PlayerState.energy, 48)

func test_only_a_weapon_swings_and_only_with_the_energy_for_it() -> void:
	var attack := _attack()
	Hotbar.select_slot(1)
	assert_false(attack.attack_selected_weapon(), "a hoe is no weapon")
	Hotbar.select_slot(0)
	PlayerState.energy = 1
	watch_signals(GameEvents)
	assert_false(attack.attack_selected_weapon())
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Not enough energy"])
	assert_eq(PlayerState.energy, 1)

func test_a_swing_does_not_start_another_while_it_runs() -> void:
	var attack := _attack()
	PlayerState.energy = 50
	var observed := {"entered": false, "inner_result": true}
	var listener := func(_current: int, _maximum: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = attack.attack_selected_weapon()
	PlayerState.energy_changed.connect(listener)
	assert_true(attack.attack_selected_weapon())
	PlayerState.energy_changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(PlayerState.energy, 50 - attack.get_energy_cost())

func _attack() -> MeleeAttack:
	var attack := MeleeAttack.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 32.0
	shape.shape = circle
	attack.add_child(shape)
	add_child_autofree(attack)
	return attack

static func _tool(id: StringName, display_name: String, action: StringName, power: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.kind = ItemData.Kind.TOOL
	item.tool_action = action
	item.tool_power = power
	item.max_stack = 1
	return item
