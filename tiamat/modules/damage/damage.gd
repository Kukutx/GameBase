class_name Damage
extends RefCounted

## One hit: the health it takes, the faction it comes from (`FactionData`),
## what dealt it, how hard it pushes what it hits (pixels a second, in real
## time) and what it lays on what it hurts besides (`affliction_id`).
## Real-time combat deals it to what it hits; other kinds of combat take it as
## a plain amount from a `Health`.

var amount: int
var faction: StringName
var source: Node
var knockback: Vector2
## The affliction the hit lays on what it hurts (`AfflictionData`), a burn or
## a poison that takes more health over time; empty, none.
var affliction_id: StringName

func _init(hit_amount := 0, hit_faction: StringName = &"", hit_source: Node = null, push := Vector2.ZERO) -> void:
	amount = maxi(hit_amount, 0)
	faction = hit_faction
	source = hit_source
	knockback = push
