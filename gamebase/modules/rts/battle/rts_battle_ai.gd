class_name RtsBattleAi
extends RefCounted

## How the units the player does not command act in a command battle
## (`RtsBattle`), every `RtsBattle.THINK_SECONDS`: when the battle has them
## advance, each with nothing to do and no foe in sight attack-moves to where
## the nearest foe stands; otherwise they wait where they stand until a foe
## comes in sight, and then go after it, as every unit with nothing to do does.

func think(battle: RtsBattle) -> void:
	if not battle.computer_advances:
		return
	for unit: RtsUnit in battle.units:
		if not unit.is_alive() or unit.player_controlled or unit.order != RtsUnit.Order.IDLE:
			continue
		if battle.get_unit(unit.target_index) != null:
			continue
		var foe := battle.get_nearest_foe(unit)
		if foe != null:
			battle.order_move([unit] as Array[RtsUnit], foe.position, true)
