class_name AfflictionLine
extends HudLine

## A line of the HUD with the afflictions on the player now and the seconds
## each lasts yet ("Burning 3s · Slimed 2s"): those on the `PlayerHurtbox` of
## the node in the "player" group. It is told again as one takes hold or wears
## off (`CombatEvents.player_afflictions_changed`) and as their seconds count
## down, and hides while there are none.

func _init() -> void:
	hides_when_empty = true

func _ready() -> void:
	super()
	set_process(false)

func _watch() -> void:
	watch(CombatEvents.player_afflictions_changed)

func _get_parts() -> PackedStringArray:
	var parts := PackedStringArray()
	var hurtbox := Hurtbox.of(get_tree().get_first_node_in_group(&"player"))
	if hurtbox != null:
		for affliction: AfflictionData in hurtbox.get_afflictions():
			var seconds := maxi(ceili(hurtbox.get_affliction_seconds_left(affliction.id) - 0.01), 1)
			parts.append(tr("%s %ds") % [tr(affliction.display_name), seconds])
	# It counts their seconds down only while there are some.
	set_process(not parts.is_empty())
	return parts

func _process(_delta: float) -> void:
	if separator.join(_get_parts()) != text:
		refresh()
