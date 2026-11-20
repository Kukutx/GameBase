extends GutTest

## The player's bow (`RangedAttack`): which item shoots, where a shot flies,
## what it hurts and what it costs.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
## The vital a shot spends.
const STAMINA := &"fixture_stamina"

## A hurtbox on the creatures' layer that counts the damage it takes.
class Target extends Hurtbox:
	var taken := 0

	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		hurt.connect(func(damage: Damage) -> void: taken += damage.amount)

var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	ContentFixture.use(self, [_tool(&"fixture_bow", "Bow", RangedAttack.TOOL_ACTION, 7), _tool(&"fixture_sword", "Sword", MeleeAttack.TOOL_ACTION, 9),
		ContentFixture.vital(STAMINA)])
	var settings := CombatSettings.new()
	settings.attack_vital_id = STAMINA
	ContentFixture.use_settings(self, [settings])
	InventoryState.clear()
	Vitals.reset_new_game()
	InventoryState.add_item_by_id(&"fixture_bow", 1)
	InventoryState.add_item_by_id(&"fixture_sword", 1)
	Hotbar.set_slot_item(0, &"fixture_bow")
	Hotbar.set_slot_item(1, &"fixture_sword")
	Hotbar.select_slot(0)

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_a_shot_flies_the_way_the_player_faces_past_friends_to_the_first_foe() -> void:
	var bow := _add_player(Vector2(9000, -9000), Vector2.RIGHT)
	var friend := _target(FactionData.PLAYER, Vector2(9050, -9000))
	var foe := _target(FactionData.MONSTERS, Vector2(9110, -9000))
	await wait_physics_frames(2)
	watch_signals(CombatEvents)
	assert_true(bow.shoot_selected_weapon())
	assert_signal_emitted_with_parameters(CombatEvents, "attack_swung", [&"fixture_bow"])
	assert_true(await wait_until(func() -> bool: return foe.taken > 0, 1.0), "it reaches the foe")
	assert_eq(foe.taken, 7, "for the bow's power")
	assert_eq(friend.taken, 0, "its own side's are passed")

func test_a_foe_a_little_off_the_way_the_player_faces_is_aimed_at() -> void:
	var bow := _add_player(Vector2(9000, -8000), Vector2.RIGHT)
	var far_off := _target(FactionData.MONSTERS, Vector2(9060, -7920))
	var near := _target(FactionData.MONSTERS, Vector2(9100, -7970))
	var farther := _target(FactionData.MONSTERS, Vector2(9140, -8000))
	await wait_physics_frames(2)
	assert_almost_eq(bow.aim().angle(), (near.global_position - Vector2(9000, -8000)).angle(), 0.001, "the nearest foe within its angle")
	assert_true(bow.shoot_selected_weapon())
	assert_true(await wait_until(func() -> bool: return near.taken > 0, 1.0))
	await wait_physics_frames(10)
	assert_eq(far_off.taken + farther.taken, 0, "and only that one")
	bow.aim_assist_degrees = 0.0
	assert_eq(bow.aim(), Vector2.RIGHT, "with no aiming help, the way the player faces")

func test_a_foe_out_of_reach_or_behind_a_wall_is_not_aimed_at() -> void:
	var bow := _add_player(Vector2(9000, -7000), Vector2.RIGHT)
	_target(FactionData.MONSTERS, Vector2(9000 + bow.distance + 30.0, -6980))
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 40)
	shape.shape = box
	wall.add_child(shape)
	wall.global_position = Vector2(9040, -7000)
	add_child_autofree(wall)
	var hidden := _target(FactionData.MONSTERS, Vector2(9080, -6990))
	await wait_physics_frames(2)
	assert_eq(bow.aim(), Vector2.RIGHT)
	assert_true(bow.shoot_selected_weapon())
	await wait_physics_frames(20)
	assert_eq(hidden.taken, 0, "the wall stops the shot")

func test_only_a_bow_shoots_for_its_cost_and_the_next_waits() -> void:
	var bow := _add_player(Vector2(9000, -6000), Vector2.DOWN)
	var swing := MeleeAttack.new()
	bow.get_parent().add_child(swing)
	assert_false(swing.attack_selected_weapon(), "a bow is not swung")
	Hotbar.select_slot(1)
	assert_false(bow.shoot_selected_weapon(), "a sword does not shoot")
	Hotbar.select_slot(0)
	bow.cooldown_seconds = 0.05
	Vitals.set_value(STAMINA, 50)
	assert_true(bow.shoot_selected_weapon())
	assert_eq(Vitals.get_value(STAMINA), 50 - bow.get_cost())
	assert_true(bow.is_cooling_down())
	assert_false(bow.shoot_selected_weapon(), "the next waits")
	assert_eq(Vitals.get_value(STAMINA), 50 - bow.get_cost(), "and costs nothing")
	await wait_physics_frames(6)
	Vitals.set_value(STAMINA, 1)
	assert_false(bow.shoot_selected_weapon(), "not without the vital for it")
	Vitals.set_value(STAMINA, 50)
	assert_true(bow.shoot_selected_weapon())

func _add_player(at: Vector2, facing: Vector2) -> RangedAttack:
	var player := TopDownPlayer.new()
	player.collision_layer = 2
	var bow := RangedAttack.new()
	player.add_child(bow)
	player.global_position = at
	add_child_autofree(player)
	player.face(facing)
	return bow

func _target(faction: StringName, at: Vector2) -> Target:
	var target := Target.new()
	target.faction = faction
	target.global_position = at
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	target.add_child(shape)
	add_child_autofree(target)
	return target

static func _tool(id: StringName, display_name: String, action: StringName, power: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.kind = ItemData.Kind.TOOL
	item.tool_action = action
	item.tool_power = power
	item.max_stack = 1
	return item
