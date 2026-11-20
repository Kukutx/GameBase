class_name EliteData
extends ContentEntry

## A stronger form any creature can take (`HostileCreature.elite`): a Hulking
## Slime is a slime with more health, a harder hit and a larger body, tinted,
## worth more experience and leaving more of its drop. A place that spawns
## creatures rolls for one (`roll()`), a dungeon more often the deeper it goes;
## `CombatEvents.elite_defeated` tells of each that falls.

const KIND := &"elite"

## Its creature's name in it, `%s` the kind's name: "Hulking %s".
@export var display_name := ""
## What must hold for a place to roll it (`GameRules` syntax; empty: always).
@export var condition := ""
## How much of its kind's health, contact damage and move speed it has.
@export_range(0.1, 10.0, 0.05) var health_scale := 1.5
@export_range(0.1, 10.0, 0.05) var damage_scale := 1.0
@export_range(0.1, 10.0, 0.05) var speed_scale := 1.0
## How much larger it is drawn, and how much it is hit where it stands.
@export_range(0.5, 3.0, 0.05) var size_scale := 1.0
## Its colour over its kind's (`EnemyData.sprite_tint`).
@export var tint := Color.WHITE
## What its hits lay on the player in place of its kind's
## (`EnemyData.affliction_id`): a searing form's burn; empty, its kind's.
@export var affliction_id: StringName
## How much of its kind's experience it is worth.
@export_range(0.0, 10.0, 0.05) var xp_scale := 1.5
## How many more of its kind's drop it leaves.
@export_range(0, 99, 1) var extra_drops := 1

## The elite with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> EliteData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as EliteData

## The running game's elites, sorted by id.
static func find_all() -> Array[EliteData]:
	var result: Array[EliteData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## One of the running game's elites whose condition holds, with chance
## `chance` (0 to 1) from `rolls`, or null. Rolls once for the chance and once
## for which, whether one comes or not, so what follows in `rolls` does not
## hang on it.
static func roll(rolls: GameRandomStream, chance: float) -> EliteData:
	var hit := rolls.randf() < chance
	var open := find_all().filter(func(elite: EliteData) -> bool: return GameRules.check(elite.condition))
	var pick := rolls.randi_range(0, maxi(open.size() - 1, 0))
	return open[pick] as EliteData if hit and not open.is_empty() else null

## The name of `enemy` in it, as the player reads it: "Hulking Slime".
func name_of(enemy: EnemyData) -> String:
	return TranslationServer.translate(display_name) % TranslationServer.translate(enemy.display_name)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if affliction_id != &"" and not registry.has_entry(AfflictionData.KIND, affliction_id):
		problems.append("lays unknown affliction '%s'" % affliction_id)
	# Not one literal, which the localization check would take for text.
	var slot := "%" + "s"
	if display_name.count(slot) != 1:
		problems.append("display name '%s' needs one %%s for its creature's name" % display_name)
	return problems
