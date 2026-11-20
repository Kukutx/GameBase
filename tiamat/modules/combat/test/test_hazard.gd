extends GutTest

## Ground that flares (`Hazard`): its cycle and warning, whom a flare hurts,
## how often, and which way it pushes.

## A hurtbox that counts the damage it takes and keeps the last push.
class Target extends Hurtbox:
	var taken := 0
	var pushed := Vector2.ZERO

	func _init(layer: int, side: StringName) -> void:
		collision_layer = layer
		collision_mask = 0
		faction = side
		# Every hit tells, so only the hazard keeps a flare to one hit.
		invincible_seconds = 0.0
		hurt.connect(func(damage: Damage) -> void:
			taken += damage.amount
			pushed = damage.knockback)

func test_it_rests_glows_to_warn_then_flares_on_its_cycle() -> void:
	var hazard := _hazard(Vector2(7000, 7000))
	hazard.rest_seconds = 0.3
	hazard.warn_seconds = 0.15
	hazard.active_seconds = 0.2
	add_child_autofree(hazard)
	assert_almost_eq(hazard.get_cycle_seconds(), 0.5, 0.001, "its rest and its flare")
	assert_false(hazard.is_active())
	assert_false(hazard.is_warning(), "it rests before it warns")
	assert_true(await wait_until(hazard.is_warning, 1.0), "then glows to warn")
	assert_false(hazard.is_active())
	watch_signals(hazard)
	assert_true(await wait_until(hazard.is_active, 1.0), "then flares")
	assert_signal_emitted(hazard, "flared")
	assert_false(hazard.is_warning(), "a flare is no warning")
	assert_true(await wait_until(func() -> bool: return not hazard.is_active(), 1.0), "and rests again")

func test_it_starts_its_phase_into_its_cycle() -> void:
	var hazard := _hazard(Vector2(7000, 7200))
	hazard.rest_seconds = 1.0
	hazard.active_seconds = 0.5
	hazard.phase_seconds = 1.2
	add_child_autofree(hazard)
	assert_true(hazard.is_active(), "a third into its flare")
	hazard = _hazard(Vector2(7000, 7400))
	hazard.rest_seconds = 1.0
	hazard.active_seconds = 0.5
	hazard.phase_seconds = 1.7
	add_child_autofree(hazard)
	assert_false(hazard.is_active(), "past one cycle it starts again")

func test_a_flare_hurts_every_side_once_and_pushes_it_away() -> void:
	var at := Vector2(7400, 7000)
	var hazard := _hazard(at)
	hazard.rest_seconds = 0.2
	hazard.active_seconds = 0.5
	hazard.damage = 6
	hazard.knockback = 50.0
	add_child_autofree(hazard)
	var player := _target(2, FactionData.PLAYER, at + Vector2(5, 0))
	var creature := _target(4, FactionData.MONSTERS, at + Vector2(-5, 0))
	await wait_for_signal(hazard.flared, 1.0)
	await wait_physics_frames(12)
	assert_true(hazard.is_active())
	assert_eq(player.taken, 6, "the player, once a flare")
	assert_eq(creature.taken, 6, "and a creature lured onto it")
	assert_almost_eq(player.pushed, Vector2(50, 0), Vector2(0.01, 0.01), "pushed away from its middle")
	assert_almost_eq(creature.pushed, Vector2(-50, 0), Vector2(0.01, 0.01))
	await wait_for_signal(hazard.flared, 1.0)
	await wait_physics_frames(2)
	assert_eq(player.taken, 12, "and once again the next")

func test_a_hazard_of_a_side_spares_its_own_and_what_stands_off_it() -> void:
	var at := Vector2(7800, 7000)
	var hazard := _hazard(at)
	hazard.rest_seconds = 0.0
	hazard.faction = FactionData.MONSTERS
	add_child_autofree(hazard)
	var player := _target(2, FactionData.PLAYER, at + Vector2(0, 6))
	var creature := _target(4, FactionData.MONSTERS, at + Vector2(0, -6))
	var away := _target(2, FactionData.PLAYER, at + Vector2(hazard.radius + 20.0, 0))
	await wait_physics_frames(6)
	assert_gt(player.taken, 0)
	assert_eq(creature.taken, 0, "its own side's")
	assert_eq(away.taken, 0, "out of its reach")
	hazard.radius = 40.0
	await wait_physics_frames(4)
	assert_gt(away.taken, 0, "a wider one reaches farther")

func test_with_no_rest_it_never_stops_and_hurts_once_every_flare() -> void:
	var at := Vector2(8200, 7000)
	var hazard := _hazard(at)
	hazard.rest_seconds = 0.0
	hazard.active_seconds = 0.25
	hazard.damage = 3
	add_child_autofree(hazard)
	var player := _target(2, FactionData.PLAYER, at)
	watch_signals(hazard)
	await wait_seconds(0.6)
	assert_true(hazard.is_active(), "it never rests")
	assert_false(hazard.is_warning())
	var hits := player.taken / 3
	assert_between(hits, 2, 4, "about once every quarter second")
	var flares: int = get_signal_emit_count(hazard, "flared")
	assert_between(hits, flares, flares + 1, "once at first and once each new flare")

func _hazard(at: Vector2) -> Hazard:
	var hazard := Hazard.new()
	hazard.global_position = at
	return hazard

func _target(layer: int, side: StringName, at: Vector2) -> Target:
	var target := Target.new(layer, side)
	target.global_position = at
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	target.add_child(shape)
	add_child_autofree(target)
	return target
