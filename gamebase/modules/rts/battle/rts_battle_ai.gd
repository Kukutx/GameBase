class_name RtsBattleAi
extends RefCounted

## How a unit the player does not command acts in a command battle
## (`RtsBattle`) when its turn to think comes, every `RtsBattle.THINK_STEPS`:
## when the battle has them advance, one with nothing to do and no foe in
## sight attack-moves to where the nearest foe stands; otherwise it waits
## where it stands until a foe comes in sight, and then goes after it, as
## every unit with nothing to do does.

func think(battle: RtsBattle, unit: RtsUnit) -> void:
	if not battle.computer_advances or unit.order != RtsUnit.Order.IDLE:
		return
	if battle.get_unit(unit.target_index) != null:
		return
	var foe := battle.get_nearest_foe(unit)
	if foe != null:
		battle.order_move([unit] as Array[RtsUnit], foe.position, true)
