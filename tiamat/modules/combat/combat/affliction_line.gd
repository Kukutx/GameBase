class_name AfflictionLine
extends HudLine

## A line of the HUD with the afflictions on the player now and the seconds
## each lasts yet ("Burning 3s · Slimed 2s", `Hurtbox.describe_afflictions()`):
## those on the `PlayerHurtbox` of the node in the "player" group. It is told
## again as one takes hold or wears off
## (`CombatEvents.player_afflictions_changed`) and as their seconds count down,
## and hides while there are none.

func _init() -> void:
	hides_when_empty = true

func _ready() -> void:
	super()
	set_process(false)

func _watch() -> void:
	watch(CombatEvents.player_afflictions_changed)

func _get_parts() -> PackedStringArray:
	var hurtbox := Hurtbox.of(get_tree().get_first_node_in_group(&"player"))
	var parts := hurtbox.describe_afflictions() if hurtbox != null else PackedStringArray()
	# It counts their seconds down only while there are some.
	set_process(not parts.is_empty())
	return parts

func _process(_delta: float) -> void:
	if separator.join(_get_parts()) != text:
		refresh()
