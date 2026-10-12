class_name WalletService
extends Node

## The player's money: shops, shipping and rewards move it, and it never drops
## below 0 (`spend()` refuses, and returns false, when there is not enough).
## The HUD follows `money_changed`. It is saved with the game, and a new game
## starts with the game's `ItemsSettings.start_money`; a save slot shows it.

signal money_changed(amount: int)

## The save section of the money.
const SAVE_SECTION := &"wallet"

var money := 0

## Whether the player has at least `amount`.
func can_afford(amount: int) -> bool:
	return money >= maxi(amount, 0)

## Gives the player `amount`; nothing for 0 or less.
func add(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

## Takes `amount` for something bought: false, and nothing taken, when the
## player has less (or `amount` is negative).
func spend(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	if amount == 0:
		return true
	money -= amount
	money_changed.emit(money)
	return true

## Takes up to `amount`, down to 0 (a loss); returns how much it took.
func lose(amount: int) -> int:
	var lost := mini(maxi(amount, 0), money)
	if lost <= 0:
		return 0
	money -= lost
	money_changed.emit(money)
	return lost

## Sets the money to `amount` (at least 0).
func set_money(amount: int) -> void:
	var next := maxi(amount, 0)
	if next == money:
		return
	money = next
	money_changed.emit(money)

func reset_new_game() -> void:
	money = -1
	set_money(ItemsSettings.current().start_money)

func to_save_data() -> Dictionary:
	return {"money": money}

func load_save_data(data: Dictionary) -> void:
	money = -1
	set_money(SaveValues.count(data.get("money", 0)))

## The money as the player reads it, translated ("120g").
func describe() -> String:
	return tr("%dg") % money

## The money `snapshot`, a save, holds.
static func read_money(snapshot: Dictionary) -> int:
	var section: Variant = snapshot.get(String(SAVE_SECTION), {})
	return SaveValues.count((section as Dictionary).get("money", 0)) if section is Dictionary else 0

## What a save slot shows of `snapshot`'s money (`SaveManager.register_slot_detail`).
func describe_save(snapshot: Dictionary) -> String:
	return tr("%dg") % read_money(snapshot)
