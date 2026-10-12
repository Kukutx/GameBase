class_name MoneyInheritance
extends InheritanceRule

## Carries a share of the player's money over (`PlayerState.money`), rounded
## down.

@export_range(0, 100, 1) var percent := 100

func _init() -> void:
	key = &"money"

func capture() -> Variant:
	return floori(PlayerState.money * percent / 100.0)

func apply(data: Variant) -> void:
	var amount := SaveValues.count(data)
	if amount > 0:
		PlayerState.add_money(amount)
