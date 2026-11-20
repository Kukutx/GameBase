class_name EnemyData
extends ContentEntry

## A kind of creature that fights the player in real time (`HostileCreature`,
## which a scene places with its id): how it looks and moves, how hard it
## hits and how it is hurt, what it lays on the player, the side it is on, and
## what it drops and is worth once defeated. An `EliteData` form makes one
## stronger.

const KIND := &"enemy"

## The name the player reads (the bestiary, where an item comes from).
@export var display_name: String = "Enemy"
## Its sprite sheet, cells of `frame_size` in rows (`SheetAnimator`); empty or
## missing, it is drawn as a shape of its `fallback_color`.
@export var sprite_path: String
## Multiplies the colours of the `sprite_path` art: one sheet in another
## palette serves another enemy (a cave slime from a green slime's sheet).
@export var sprite_tint := Color.WHITE
## The colour of the shape an enemy is drawn as while it has no `sprite_path` art.
@export var fallback_color := Color(0.35, 0.75, 0.38)
## The size of a cell of its sheet, in pixels.
@export var frame_size := Vector2i(32, 32)
## How fast its frames play.
@export_range(1, 60, 1) var animation_fps := 12
## The first and last frames, counted from 0 along the rows of its sheet, it
## plays standing, moving and once when defeated (that long it lies there).
@export_range(0, 999, 1) var idle_from := 0
@export_range(0, 999, 1) var idle_to := 0
@export_range(0, 999, 1) var move_from := 0
@export_range(0, 999, 1) var move_to := 0
@export_range(0, 999, 1) var death_from := 0
@export_range(0, 999, 1) var death_to := 0
## Its health, before the player's foe strength scales it.
@export_range(1, 999, 1) var max_health := 30
## How fast it moves, in pixels a second.
@export_range(1.0, 300.0, 1.0) var move_speed := 36.0
## How near the player must come for it to chase them; farther, it gives up.
@export_range(8.0, 400.0, 1.0) var chase_radius := 110.0
## How near the player must be for it to strike, or to shoot (`shot_speed`).
@export_range(4.0, 320.0, 1.0) var attack_range := 16.0
## The damage of each strike or shot.
@export_range(0, 999, 1) var contact_damage := 8
## How long it waits after a strike or a shot before the next.
@export_range(0.1, 10.0, 0.1, "suffix:s") var attack_cooldown := 1.2
## How long it winds up a strike once the player is in reach, standing still
## and glowing (`HostileCreature.windup_color`), so the player sees it coming:
## a step out of reach or a hit that stuns it before it lands spares them.
## 0 strikes at once (a slime that hurts at a touch).
@export_range(0.0, 2.0, 0.05) var windup_seconds := 0.0
## With a speed, it strikes from afar: it throws a shot (`Projectile`) that
## flies this fast, in pixels a second, at where the player stands, for its
## `contact_damage`, and fades past half again its `attack_range`; a wall
## stops it and a step aside dodges it. It backs away from a player who comes
## near (`HostileCreature.SHOT_KEEP_AWAY`). 0 strikes in reach.
@export_range(0.0, 600.0, 1.0) var shot_speed := 0.0
## The colour its shots glow in.
@export var shot_color := Color(1.0, 0.62, 0.25)
## What its strikes and shots lay on the player they hurt besides
## (`AfflictionData`): an ember wisp's embers burn; empty, nothing.
@export var affliction_id: StringName
## The afflictions that never take hold of it (`Hurtbox.immune_to`): an ember
## wisp does not burn.
@export var immune_to: Array[StringName] = []
## The side it fights on (`FactionData`): it hurts and is hurt by the others.
@export var faction_id: StringName = FactionData.MONSTERS
## How hard its strike pushes the player, in pixels a second.
@export_range(0.0, 600.0, 1.0) var knockback := 90.0
## How far a hit pushes it: 0 for not at all, 1 for the hit's full push.
@export_range(0.0, 4.0, 0.05) var knockback_scale := 1.0
## The box it stands in and is hit in, in pixels.
@export var collision_size := Vector2(16, 12)
## Where its sprite is drawn from where it stands, in pixels.
@export var visual_offset := Vector2(0, -5)
## How large its sprite is drawn.
@export_range(0.1, 4.0, 0.05) var visual_scale := 1.0
## The item (`ItemData`) it drops when defeated; empty, none.
@export var drop_item_id: StringName
## How many of it it drops, before the player's loot stat and an elite's
## extra.
@export_range(0, 99, 1) var drop_quantity := 1
## How many days after its defeat it comes back.
@export_range(1, 28, 1) var respawn_days := 1
## Combat experience a defeat is worth, which `CombatEvents.enemy_defeated`
## passes on for the game to award (0: none).
@export_range(0, 9999, 1) var combat_xp := 20

## The enemy with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> EnemyData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as EnemyData

## The running game's enemies, sorted by id.
static func find_all() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func has_valid_animation_ranges() -> bool:
	return idle_from <= idle_to and move_from <= move_to and death_from <= death_to

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not has_valid_animation_ranges():
		problems.append("has invalid animation ranges")
	if drop_item_id != &"" and not registry.has_entry(ItemData.KIND, drop_item_id):
		problems.append("references unknown drop '%s'" % drop_item_id)
	if affliction_id != &"" and not registry.has_entry(AfflictionData.KIND, affliction_id):
		problems.append("lays unknown affliction '%s'" % affliction_id)
	for immune: StringName in immune_to:
		if not registry.has_entry(AfflictionData.KIND, immune):
			problems.append("is immune to unknown affliction '%s'" % immune)
	if faction_id == &"":
		problems.append("has no faction")
	elif not FactionData.are_hostile(faction_id, FactionData.PLAYER):
		problems.append("fights on the player's side")
	return problems
