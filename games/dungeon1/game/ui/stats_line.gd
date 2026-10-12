class_name DelverStatsLine
extends HudLine

## What the delver has: their vitals, their money and their combat level.

func _watch() -> void:
	watch(Vitals.changed)
	watch(Wallet.money_changed)
	watch(Skills.skill_xp_changed)

func _get_parts() -> PackedStringArray:
	var parts := Vitals.describe_all()
	parts.append(Wallet.describe())
	parts.append(tr("Combat Lv %d") % Skills.get_level(&"combat"))
	return parts
