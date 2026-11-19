class_name MoneyInheritance
extends InheritanceRule

## Carries a share of the player's money (`Wallet`) over, rounded down.

@export_range(0, 100, 1) var percent := 100

func _init() -> void:
	key = &"money"

func capture() -> Variant:
	return floori(Wallet.money * percent / 100.0)

func apply(data: Variant) -> void:
	var amount := SaveValues.count(data)
	if amount > 0:
		Wallet.add(amount)
