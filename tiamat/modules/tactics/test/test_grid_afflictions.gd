extends GutTest

## Afflictions in a grid battle (`BattleActionData.affliction_id`,
## `GridUnit.afflict()`): an action lays one on the foes it leaves standing,
## which the forecast tells; it ticks in battle time, which stands still while
## the player chooses; its last tick of a unit's health defeats it and can end
## the battle; a kind immune to it never takes it; the foes' plans count it;
## and what is wrong with the content that names one.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const TacticsFixture := preload("res://tiamat/modules/tactics/test/tactics_fixture.gd")
const POISON := &"fixture_poison"

func before_each() -> void:
	ContentFixture.use(self, TacticsFixture.entries())

func test_an_action_lays_its_affliction_which_ticks_in_battle_time() -> void:
	var battle := TacticsFixture.battle()
	var adder := _add(battle, &"fixture_adder", FactionData.PLAYER, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	var poison := AfflictionData.find(POISON)
	var venom := BattleActionData.find(&"fixture_venom")
	watch_signals(battle)
	TacticsFixture.give_turn(battle, adder)
	assert_eq(battle.forecast(adder, venom, raider.cell)[0].get("affliction"), poison, "the forecast tells it")
	assert_true(battle.act(adder, venom, raider.cell))
	assert_eq(raider.health.current, 10, "the adder's 3 less the raider's 1")
	var hits: Array = get_signal_parameters(battle, "unit_acted")[3]
	assert_eq(hits[0].get("affliction"), poison, "the hit tells it")
	assert_true(raider.afflictions.has(POISON))
	battle.advance(3.0)
	assert_eq(raider.health.current, 10, "time stands still while the adder's turn waits")
	battle.time_flows_while_choosing = true
	assert_true(battle.end_turn(adder))
	battle.advance(2.5)
	assert_eq(raider.health.current, 8, "a tick each second of battle time")
	assert_signal_emitted_with_parameters(battle, "unit_ailed", [raider, poison, 1])
	battle.advance(2.0)
	assert_eq(raider.health.current, 6, "four ticks in all")
	assert_signal_emit_count(battle, "unit_ailed", 4)
	assert_true(raider.afflictions.is_empty(), "then it wears off")

func test_the_tick_that_takes_the_last_health_defeats_a_unit_and_can_end_the_battle() -> void:
	var battle := TacticsFixture.battle()
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 5))
	watch_signals(battle)
	raider.health.take(10)
	assert_true(raider.afflict(AfflictionData.find(POISON), FactionData.PLAYER))
	battle.advance(1.5)
	assert_eq(raider.health.current, 1)
	battle.advance(1.0)
	assert_false(raider.is_alive())
	assert_signal_emitted_with_parameters(battle, "unit_defeated", [raider])
	assert_true(battle.is_over() and battle.is_won(), "the player's last foe gone, before the knight's turn at the same moment")
	assert_true(raider.afflictions.is_empty(), "a fallen unit's afflictions go with it")

func test_a_kind_immune_to_it_never_takes_it_and_the_foes_plans_count_it() -> void:
	var battle := TacticsFixture.battle()
	var adder := _add(battle, &"fixture_adder", FactionData.MONSTERS, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.PLAYER, Vector2i(1, 0))
	var venom := BattleActionData.find(&"fixture_venom")
	var poison := AfflictionData.find(POISON)
	var ai := GridBattleAi.new()
	assert_eq(ai.score(battle, adder, venom, raider.cell, adder.cell), 2 + 4, "its bite and the poison's four ticks")
	assert_true(raider.afflict(poison, FactionData.MONSTERS))
	assert_eq(ai.score(battle, adder, venom, raider.cell, adder.cell), 2, "not on a raider poisoned already")
	raider.afflictions.clear()
	raider.data.immune_to.assign([POISON])
	assert_false(raider.can_be_afflicted(poison))
	assert_false(raider.afflict(poison, FactionData.MONSTERS))
	assert_false(battle.forecast(adder, venom, raider.cell)[0].has("affliction"), "the forecast leaves it out")
	assert_eq(ai.score(battle, adder, venom, raider.cell, adder.cell), 2, "nor on one immune to it")
	assert_false(raider.afflict(null, FactionData.MONSTERS))

func test_what_is_wrong_with_an_action_or_a_unit_that_names_an_affliction() -> void:
	var registry := ContentRegistry.active
	var venom := BattleActionData.find(&"fixture_venom")
	assert_eq(venom.find_problems(registry), PackedStringArray())
	venom.affliction_id = &"fixture_missing"
	assert_eq(venom.find_problems(registry), PackedStringArray(["lays unknown affliction 'fixture_missing'"]))
	var mend := BattleActionData.find(&"fixture_mend")
	mend.affliction_id = POISON
	assert_eq(mend.find_problems(registry), PackedStringArray(["lays an affliction on the units it heals"]))
	var raider := BattleUnitData.find(&"fixture_raider")
	raider.immune_to.assign([&"fixture_missing"])
	assert_eq(raider.find_problems(registry), PackedStringArray(["is immune to unknown affliction 'fixture_missing'"]))

func _add(battle: AtbBattle, unit_id: StringName, faction: StringName, cell: Vector2i) -> GridUnit:
	return battle.add_unit(BattleUnitData.find(unit_id), faction, cell)
