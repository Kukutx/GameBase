extends GutTest

## How a unit the player does not command takes its turn (`GridBattleAi`): a
## defeat before more damage, a move only to bring a target in reach, a heal
## for its hurt side, and a walk toward the nearest foe when nothing is in
## reach.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TacticsFixture := preload("res://gamebase/modules/tactics/test/tactics_fixture.gd")

func before_each() -> void:
	ContentFixture.use(self, TacticsFixture.entries())

func test_a_defeat_comes_before_more_damage() -> void:
	var battle := TacticsFixture.battle()
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 2))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(2, 1))
	var archer := _add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(3, 2))
	archer.health.set_current(6)
	assert_eq(battle.ai.best_plan(battle, raider)["target"], Vector2i(3, 2))
	TacticsFixture.give_turn(battle, raider)
	assert_false(archer.is_alive(), "6 defeats the archer; the knight would only lose 4")
	assert_eq(knight.health.current, 20)
	assert_eq(raider.cell, Vector2i(2, 2), "no need to move")

func test_it_moves_to_bring_a_foe_in_reach_then_strikes() -> void:
	var battle := TacticsFixture.battle()
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 0))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 0))
	TacticsFixture.give_turn(battle, raider)
	assert_eq(raider.cell, Vector2i(2, 0))
	assert_eq(knight.health.current, 16)

func test_a_healer_mends_its_hurt_side() -> void:
	var battle := TacticsFixture.battle()
	var healer := _add(battle, &"fixture_healer", FactionData.MONSTERS, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(7, 5))
	raider.health.set_current(4)
	TacticsFixture.give_turn(battle, healer)
	assert_eq(raider.health.current, 9)

func test_with_nothing_in_reach_it_walks_toward_the_nearest_foe_or_stays_when_none_can_be_reached() -> void:
	var battle := TacticsFixture.battle()
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 0))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(7, 5))
	var near := _add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(0, 5))
	assert_true(battle.ai.best_plan(battle, raider).is_empty())
	TacticsFixture.give_turn(battle, raider)
	assert_eq(raider.cell, Vector2i(0, 3), "three cells toward the archer, five away, not the knight, twelve away")
	assert_eq(BattleGrid.distance(raider.cell, near.cell), 2)

	# A wall of water between them.
	var walled := TacticsFixture.battle(Vector2i(5, 3), [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)] as Array[Vector2i])
	var stuck := _add(walled, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 1))
	_add(walled, &"fixture_knight", FactionData.PLAYER, Vector2i(4, 1))
	TacticsFixture.give_turn(walled, stuck)
	assert_eq(stuck.cell, Vector2i(0, 1))

func _add(battle: AtbBattle, unit_id: StringName, faction: StringName, cell: Vector2i) -> GridUnit:
	return battle.add_unit(BattleUnitData.find(unit_id), faction, cell)
