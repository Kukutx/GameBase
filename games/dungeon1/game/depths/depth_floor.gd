class_name DepthFloor
extends Node2D

## The root of the depths' scene: one floor of a run. It lays out the enemies
## of the run's depth (`DepthRun`) from `enemy_tiers` with the run's random
## stream, so a floor comes back the same only within the same run. Once every
## enemy is defeated the way on opens: the stairs down to the next depth, or
## the rope back up to camp with what the player found; and the ember altar
## lights, where the player takes one of three boons for the run (`BoonAltar`,
## one for each depth of a run). A depth a guardian tier guards
## (`EnemyTier.guardian_every`: the Ember Warden every fifth depth) holds its
## guardian and half the creatures, and the way on opens once it falls.
## A creature may come in an elite form (`EliteData`: Hulking, Swift,
## Searing), the more often the deeper (`elite_odds`). Ember vents (`Hazard`,
## spread by `vents`) flare on the floor in turn, burning the player and the
## creatures alike, more of them the deeper, from a stream of their own and
## clear of the ways in and on and the altar.

const ENEMY_SCENE := preload("res://tiamat/modules/combat/combat/hostile_creature.tscn")
# How far apart the enemies of a floor stand.
const ENEMY_SPACING := 28.0
# How far a floor's vents stand from the ways in and on and the altar.
const VENT_CLEARANCE := 48.0

## The enemies floors spawn, each from its minimum depth on; deeper tiers come
## up more often, and a guardian tier's enemy only at the depths it guards.
@export var enemy_tiers: Array[EnemyTier] = []
## How often its ordinary creatures come as elites; none without.
@export var elite_odds: EliteOdds
## Where enemies may stand, in the scene's coordinates.
@export var arena := Rect2(-200, -110, 400, 220)
## The spawn point the player arrives at; enemies keep `arrival_clearance` away.
@export var arrival_spawn_id: StringName = &"arrival"
@export var arrival_clearance := 90.0
## The ember vents of its floors, the deeper the more; none without.
@export var vents: HazardSpread
## Where the rope leads.
@export var camp_location_id: StringName
@export var camp_spawn_id: StringName

@onready var depth_label: Label = $DepthLabel
@onready var stairs: Node2D = $Stairs
@onready var rope: Node2D = $Rope
@onready var altar: BoonAltar = $EmberAltar

var _enemies: Array[HostileCreature] = []
var _guardians: Array[HostileCreature] = []
var _vents: Array[Hazard] = []

func _ready() -> void:
	(stairs.get_node("Interactable") as Interactable).interacted.connect(_descend)
	(rope.get_node("Interactable") as Interactable).interacted.connect(_climb)
	altar.key = "depth%d" % DepthRun.get_depth()
	altar.boon_taken.connect(func(_boon_id: StringName) -> void: _refresh())
	CombatEvents.enemy_defeated.connect(_on_enemy_defeated)
	GameSettings.locale_changed.connect(_on_locale_changed)
	_spawn_vents()
	_spawn_enemies()
	_refresh()

## How many creatures a floor at `depth` spawns besides its guardians: half
## as many where a guardian stands (`guarded`).
static func get_enemy_count(depth: int, guarded := false) -> int:
	var count := clampi(2 + depth / 2, 2, 8)
	return count / 2 if guarded else count

## The floor's ember vents.
func get_vents() -> Array[Hazard]:
	return _vents.duplicate()

func get_enemies() -> Array[HostileCreature]:
	return _enemies.duplicate()

## The floor's guardians (`EnemyTier.guardians()`), defeated or not.
func get_guardians() -> Array[HostileCreature]:
	return _guardians.duplicate()

## What the HUD's place line (`PlaceLine`) adds on this floor: its depth.
func get_place_detail() -> String:
	return tr("Depth %d") % DepthRun.get_depth()

## Whether every enemy of the floor is defeated.
func is_cleared() -> bool:
	for enemy: HostileCreature in _enemies:
		if is_instance_valid(enemy) and not enemy.is_defeated:
			return false
	return true

func _spawn_enemies() -> void:
	var depth := DepthRun.get_depth()
	var kinds := EnemyTier.reached(enemy_tiers, depth)
	if kinds.is_empty():
		return
	var guardian_kinds := EnemyTier.guardians(enemy_tiers, depth)
	var rng := DepthRun.floor_stream()
	# A stream of their own, so the elites leave the floor's layout as it was.
	var elite_rolls := DepthRun.floor_stream("elites")
	var arrival := _spawn_position(arrival_spawn_id)
	var clear_of_arrival := func(point: Vector2) -> bool: return point.distance_to(arrival) >= arrival_clearance
	var count := guardian_kinds.size() + get_enemy_count(depth, not guardian_kinds.is_empty())
	var positions: Array[Vector2] = []
	# None starts on a vent.
	var vent_places := PackedVector2Array()
	for vent: Hazard in _vents:
		vent_places.append(vent.position)
	positions.assign(Array(rng.scatter(arena, count, ENEMY_SPACING, vent_places, Vector2(8, 8), clear_of_arrival)))
	# The guardians stand furthest from where the player arrives.
	if not guardian_kinds.is_empty():
		positions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(arrival) > b.distance_to(arrival))
	for index: int in positions.size():
		var guardian := index < guardian_kinds.size()
		# The larger of two rolls, so the deeper of the reached tiers come up more.
		var kind := guardian_kinds[index] if guardian else kinds[maxi(rng.randi_range(0, kinds.size() - 1), rng.randi_range(0, kinds.size() - 1))]
		var enemy := ENEMY_SCENE.instantiate() as HostileCreature
		enemy.name = "Guardian%02d" % (index + 1) if guardian else "Enemy%02d" % (index + 1)
		enemy.data = EnemyData.find(kind)
		enemy.elite = null if guardian or elite_odds == null else elite_odds.roll(elite_rolls, depth)
		enemy.position = positions[index]
		add_child(enemy)
		_enemies.append(enemy)
		if guardian:
			_guardians.append(enemy)
	if not _guardians.is_empty():
		GameEvents.toastf("%s guards this depth", [_guardians[0].data.display_name])

func _spawn_vents() -> void:
	if vents == null:
		return
	var depth := DepthRun.get_depth()
	var rolls := DepthRun.floor_stream("vents")
	var keep_clear: Array[Vector2] = [_spawn_position(arrival_spawn_id), stairs.position, rope.position, altar.position]
	var clear := func(point: Vector2) -> bool:
		for spot: Vector2 in keep_clear:
			if point.distance_to(spot) < VENT_CLEARANCE:
				return false
		return true
	for place: Vector2 in vents.spread(rolls, depth, arena.grow(-16.0), PackedVector2Array(), clear):
		var vent := vents.make(depth, rolls.randf())
		if vent == null:
			continue
		vent.name = "Vent%02d" % (_vents.size() + 1)
		vent.position = place
		Hazard.add_under_actors(self, vent)
		_vents.append(vent)

func _spawn_position(spawn_id: StringName) -> Vector2:
	for child: Node in get_children():
		if child is WorldSpawnPoint and (child as WorldSpawnPoint).spawn_id == spawn_id:
			return (child as Node2D).position
	return Vector2.ZERO

func _descend(_actor: Node) -> void:
	var location := WorldLocationData.find_for_scene(scene_file_path)
	if location == null or not is_cleared() or not WorldTravel.can_travel_to(location.id, arrival_spawn_id):
		return
	if DepthRun.descend():
		WorldTravel.travel_to(location.id, arrival_spawn_id)

func _climb(_actor: Node) -> void:
	if is_cleared() and WorldTravel.travel_to(camp_location_id, camp_spawn_id):
		DepthRun.return_to_camp()

func _on_enemy_defeated(_enemy_id: StringName, _combat_xp: int, _position: Vector2) -> void:
	_refresh.call_deferred()

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _refresh() -> void:
	var cleared := is_cleared()
	for way: Node2D in [stairs, rope]:
		way.visible = cleared
		(way.get_node("Interactable") as Interactable).enabled = cleared
	altar.visible = cleared and not altar.is_spent() and RunState.is_active()
	altar.refresh()
	altar.interactable.enabled = altar.interactable.enabled and cleared
	depth_label.text = tr("Depth %d · Deepest %d") % [DepthRun.get_depth(), DepthRun.get_deepest()]
	if cleared and not _enemies.is_empty():
		depth_label.text += "\n" + tr("The way on is open")
	for guardian: HostileCreature in _guardians:
		if is_instance_valid(guardian) and not guardian.is_defeated:
			depth_label.text += "\n" + tr("%s guards this depth") % tr(guardian.data.display_name)
			break

func find_scene_problems(registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	for problem: String in EnemyTier.find_problems(enemy_tiers, registry):
		problems.append("depth floor %s" % problem)
	if EnemyTier.reached(enemy_tiers, 1).is_empty():
		problems.append("depth floor has no enemy tier from depth 1")
	if location != null and not registry.has_location_spawn(location.id, arrival_spawn_id):
		problems.append("depth floor arrives at spawn '%s', which its scene does not have" % arrival_spawn_id)
	if not registry.has_location_spawn(camp_location_id, camp_spawn_id):
		problems.append("depth floor's rope leads to spawn '%s' of '%s', which does not exist" % [camp_spawn_id, camp_location_id])
	return problems
