extends GutTest

## A creature's shot (`CreatureShot`) and the creatures that shoot
## (`EnemyData.shot_speed`).

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const HOSTILE_CREATURE_SCENE := preload("res://tiamat/modules/combat/combat/hostile_creature.tscn")

var _vitals_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_vitals_snapshot = Vitals.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	ContentFixture.use(self, [_wisp(), ContentFixture.vital(&"fixture_hp")])
	var settings := CombatSettings.new()
	settings.health_vital_id = &"fixture_hp"
	ContentFixture.use_settings(self, [settings])
	WorldState.clear()
	Vitals.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	Vitals.load_save_data(_vitals_snapshot)
	WorldState.load_save_data(_world_snapshot)
	# The creatures the test left go after this hook; their fight goes now.
	FightState.end_fight()

func test_a_shot_flies_to_the_player_hurts_them_and_is_gone() -> void:
	var player := _add_player(Vector2(6060, 6000))
	var shot := CreatureShot.fire(_add_spot(Vector2(6000, 6000)), player.global_position, 300.0, 200.0, Damage.new(7, FactionData.MONSTERS), Color.ORANGE)
	assert_eq(shot.global_position, Vector2(6000, 6000), "from where it was thrown")
	assert_true(await wait_until(func() -> bool: return not Vitals.is_full(&"fixture_hp"), 1.0), "it reaches the player")
	assert_eq(Vitals.get_value(&"fixture_hp"), 93)
	await get_tree().process_frame
	assert_false(is_instance_valid(shot), "and lands only once")

func test_a_shot_spares_its_own_side_and_fades_past_its_reach() -> void:
	var ally := _add_actor(Vector2(6030, 6000), FactionData.MONSTERS)
	watch_signals(Hurtbox.of(ally))
	_add_player(Vector2(6160, 6000))
	var shot := CreatureShot.fire(_add_spot(Vector2(6000, 6000)), Vector2(6160, 6000), 400.0, 100.0, Damage.new(7, FactionData.MONSTERS), Color.ORANGE)
	assert_true(await wait_until(_gone(shot), 1.0), "it fades once it flew its reach")
	assert_signal_not_emitted(Hurtbox.of(ally), "hurt", "its own side's are not hurt")
	assert_true(Vitals.is_full(&"fixture_hp"), "and the player beyond its reach is spared")

func test_a_wall_stops_a_shot() -> void:
	var wall := StaticBody2D.new()
	wall.add_child(_box(Vector2(8, 64)))
	wall.global_position = Vector2(6040, 6000)
	add_child_autofree(wall)
	_add_player(Vector2(6080, 6000))
	await get_tree().physics_frame
	var shot := CreatureShot.fire(_add_spot(Vector2(6000, 6000)), Vector2(6080, 6000), 300.0, 200.0, Damage.new(7, FactionData.MONSTERS), Color.ORANGE)
	assert_true(await wait_until(_gone(shot), 1.0))
	await wait_physics_frames(10)
	assert_true(Vitals.is_full(&"fixture_hp"), "the player behind the wall is spared")

func test_a_creature_that_shoots_hurts_from_afar() -> void:
	var player := _add_player(Vector2(7000, 7000))
	var wisp := _add_wisp(player.global_position + Vector2(80, 0))
	assert_true(await wait_until(func() -> bool: return not _shots().is_empty(), 1.0), "the player in its reach")
	assert_gt(wisp.global_position.distance_to(player.global_position), 50.0, "it shoots without closing in")
	assert_eq(_shots().size(), 1, "one at a time, its cooldown between")
	assert_true(await wait_until(func() -> bool: return not Vitals.is_full(&"fixture_hp"), 2.0), "the shot lands")
	assert_eq(Vitals.get_value(&"fixture_hp"), 100 - wisp.data.contact_damage)

func test_a_step_aside_dodges_a_shot() -> void:
	var player := _add_player(Vector2(7000, 7000))
	_add_wisp(player.global_position + Vector2(80, 0))
	assert_true(await wait_until(func() -> bool: return not _shots().is_empty(), 1.0))
	var shot := _shots()[0]
	player.global_position += Vector2(0, 40)
	assert_true(await wait_until(_gone(shot), 2.0))
	assert_true(Vitals.is_full(&"fixture_hp"), "it flies on where the player stood")

func test_a_creature_that_shoots_backs_away_from_a_player_who_comes_near() -> void:
	var player := _add_player(Vector2(7000, 7000))
	var wisp := _add_wisp(player.global_position + Vector2(20, 0))
	await wait_physics_frames(20)
	assert_gt(wisp.global_position.x, 7025.0, "it backs away")
	assert_eq(wisp.get_state(), HostileCreature.STATE_CHASE, "still after the player")

# On the games' layers: the player's 2, the creatures' 3.
func _add_player(at: Vector2) -> CharacterBody2D:
	var player := _add_actor(at, FactionData.PLAYER, 2, PlayerHurtbox.new())
	player.add_to_group(&"player")
	return player

func _add_actor(at: Vector2, faction: StringName, layer := 4, hurtbox := Hurtbox.new()) -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	actor.collision_layer = layer
	hurtbox.collision_layer = layer
	hurtbox.faction = faction
	hurtbox.add_child(_box(Vector2(12, 12)))
	actor.add_child(hurtbox)
	actor.global_position = at
	add_child_autofree(actor)
	return actor

func _add_spot(at: Vector2) -> Node2D:
	var spot := Node2D.new()
	spot.global_position = at
	add_child_autofree(spot)
	return spot

func _add_wisp(at: Vector2) -> HostileCreature:
	var wisp := HOSTILE_CREATURE_SCENE.instantiate() as HostileCreature
	wisp.data = EnemyData.find(&"fixture_wisp")
	wisp.global_position = at
	add_child_autofree(wisp)
	return wisp

func _shots() -> Array[CreatureShot]:
	var shots: Array[CreatureShot] = []
	for child in get_children():
		if child is CreatureShot and not (child as CreatureShot).is_spent():
			shots.append(child)
	return shots

# Whether `shot` is gone, without holding on to it.
func _gone(shot: CreatureShot) -> Callable:
	var held: WeakRef = weakref(shot)
	return func() -> bool: return held.get_ref() == null

func _box(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	return shape

# A creature that shoots from afar for 11 and keeps its distance.
func _wisp() -> EnemyData:
	var wisp := EnemyData.new()
	wisp.id = &"fixture_wisp"
	wisp.display_name = "Wisp"
	wisp.max_health = 20
	wisp.chase_radius = 200.0
	wisp.attack_range = 96.0
	wisp.contact_damage = 11
	wisp.attack_cooldown = 1.6
	wisp.shot_speed = 140.0
	return wisp
