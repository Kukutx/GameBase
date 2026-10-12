extends GutTest

## The player's melee attack (`MeleeAttack`): which item swings, what a swing
## costs, what it hits, how soon it swings again and the arc it draws.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
## The vital a swing spends.
const STAMINA := &"fixture_stamina"

## A hurtbox that counts the damage it takes.
class Target extends Hurtbox:
	var taken := 0

	func _init() -> void:
		hurt.connect(func(damage: Damage) -> void: taken += damage.amount)

var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _buff_snapshot: Dictionary
var _reduced_motion := false

func before_each() -> void:
	_reduced_motion = GameSettings.reduced_motion
	GameSettings.reduced_motion = true
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_buff_snapshot = BuffState.to_save_data()
	ContentFixture.use(self, [_tool(&"fixture_sword", "Sword", MeleeAttack.TOOL_ACTION, 7), _tool(&"fixture_hoe", "Hoe", &"fixture_till", 1),
		ContentFixture.vital(STAMINA)])
	var settings := CombatSettings.new()
	settings.attack_vital_id = STAMINA
	ContentFixture.use_settings(self, [settings])
	InventoryState.clear()
	Vitals.reset_new_game()
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
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	BuffState.load_save_data(_buff_snapshot)
	GameSettings.reduced_motion = _reduced_motion

func test_a_swing_hits_the_hostile_hurtboxes_in_reach_for_the_weapon_s_power() -> void:
	var attack := _attack()
	var target := _target(FactionData.MONSTERS, Vector2(10, 0))
	var friend := _target(FactionData.PLAYER, Vector2(-10, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	Vitals.set_value(STAMINA, 50)
	watch_signals(CombatEvents)
	assert_true(attack.attack_selected_weapon())
	assert_eq(target.taken, 7)
	assert_eq(friend.taken, 0, "the swing's own side")
	assert_eq(Vitals.get_value(STAMINA), 50 - attack.get_cost())
	assert_signal_emitted_with_parameters(CombatEvents, "attack_swung", [&"fixture_sword"])

func test_a_swing_at_nothing_still_costs_and_draws_its_arc() -> void:
	var attack := _attack()
	attack.position = Vector2(0, -16)
	Vitals.set_value(STAMINA, 50)
	assert_true(attack.attack_selected_weapon())
	assert_eq(Vitals.get_value(STAMINA), 48)
	var swings := attack.get_children().filter(func(child: Node) -> bool: return child is SwingEffect)
	assert_eq(swings.size(), 1)
	assert_almost_eq((swings[0] as SwingEffect).rotation, Vector2.UP.angle(), 0.001, "turned the way the swing goes")
	await wait_seconds(SwingEffect.SECONDS + 0.1)
	assert_false(attack.get_children().any(func(child: Node) -> bool: return child is SwingEffect), "the arc is gone once it faded")
	assert_eq((attack.get("_swings") as NodePool).get_kept_count(), 1, "kept for the next swing")

func test_the_next_swing_waits_for_the_cooldown() -> void:
	var attack := _attack()
	attack.cooldown_seconds = 0.05
	Vitals.set_value(STAMINA, 50)
	assert_true(attack.attack_selected_weapon())
	assert_true(attack.is_cooling_down())
	assert_false(attack.attack_selected_weapon())
	assert_eq(Vitals.get_value(STAMINA), 48, "a swing that waits costs nothing")
	await wait_physics_frames(6)
	assert_true(attack.attack_selected_weapon())

func test_only_a_weapon_swings_and_only_with_the_vital_for_it() -> void:
	var attack := _attack()
	Hotbar.select_slot(1)
	assert_false(attack.attack_selected_weapon(), "a hoe is no weapon")
	Hotbar.select_slot(0)
	Vitals.set_value(STAMINA, 1)
	watch_signals(GameEvents)
	assert_false(attack.attack_selected_weapon())
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Not enough Stamina"])
	assert_eq(Vitals.get_value(STAMINA), 1)

func test_a_swing_does_not_start_another_while_it_runs() -> void:
	var attack := _attack()
	Vitals.set_value(STAMINA, 50)
	var observed := {"entered": false, "inner_result": true}
	var listener := func(_vital_id: StringName, _current: int, _maximum: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = attack.attack_selected_weapon()
	Vitals.changed.connect(listener)
	assert_true(attack.attack_selected_weapon())
	Vitals.changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(Vitals.get_value(STAMINA), 50 - attack.get_cost())

func _target(faction: StringName, at: Vector2) -> Target:
	var target := Target.new()
	target.faction = faction
	target.position = at
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	target.add_child(shape)
	add_child_autofree(target)
	return target

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
