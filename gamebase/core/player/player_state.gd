class_name GlobalPlayerState
extends Node

signal energy_changed(current: int, maximum: int)
signal health_changed(current: int, maximum: int)
signal money_changed(amount: int)

@export_range(1, 999, 1) var max_energy := 100
@export_range(1, 999, 1) var max_health := 100

var energy := 100
var health := 100
var money := GameDefinition.current().start_money

func consume_energy(amount: int) -> bool:
	if amount <= 0:
		return true
	if energy < amount:
		return false
	energy -= amount
	energy_changed.emit(energy, max_energy)
	return true

func restore_energy(amount: int) -> void:
	if amount <= 0:
		return
	var next := mini(energy + amount, max_energy)
	if next == energy:
		return
	energy = next
	energy_changed.emit(energy, max_energy)

func set_energy(amount: int) -> void:
	var next := clampi(amount, 0, max_energy)
	if next == energy:
		return
	energy = next
	energy_changed.emit(energy, max_energy)

func restore_full_energy() -> void:
	energy = max_energy
	energy_changed.emit(energy, max_energy)

func take_damage(amount: int) -> bool:
	if amount <= 0 or health <= 0:
		return false
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	return true

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var next := mini(health + amount, max_health)
	if next == health:
		return
	health = next
	health_changed.emit(health, max_health)

func restore_full_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	if amount == 0:
		return true
	money -= amount
	money_changed.emit(money)
	return true

func lose_money(amount: int) -> int:
	var lost := mini(maxi(amount, 0), money)
	if lost <= 0:
		return 0
	money -= lost
	money_changed.emit(money)
	return lost

func reset_new_game() -> void:
	energy = max_energy
	health = max_health
	money = GameDefinition.current().start_money
	energy_changed.emit(energy, max_energy)
	health_changed.emit(health, max_health)
	money_changed.emit(money)

func to_save_data() -> Dictionary:
	return {
		"max_energy": max_energy,
		"energy": energy,
		"max_health": max_health,
		"health": health,
		"money": money,
	}

func load_save_data(data: Dictionary) -> void:
	max_energy = maxi(SaveValues.whole_number_or(data.get("max_energy", 100), 100), 1)
	energy = clampi(SaveValues.whole_number_or(data.get("energy", max_energy), max_energy), 0, max_energy)
	max_health = maxi(SaveValues.whole_number_or(data.get("max_health", 100), 100), 1)
	health = clampi(SaveValues.whole_number_or(data.get("health", max_health), max_health), 0, max_health)
	var start_money := GameDefinition.current().start_money
	money = maxi(SaveValues.whole_number_or(data.get("money", start_money), start_money), 0)
	energy_changed.emit(energy, max_energy)
	health_changed.emit(health, max_health)
	money_changed.emit(money)
