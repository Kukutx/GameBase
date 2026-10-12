class_name DamageModule
extends GameModule

## Wires the damage module into the core (see `GameModule`): what every kind
## of fight shares, its health (`Health`), its hits (`Damage`) and its sides
## (`FactionData`), whether in real time, on a grid or on an open field.

func install() -> void:
	ContentDB.register_kind(FactionData.KIND, FactionData)
