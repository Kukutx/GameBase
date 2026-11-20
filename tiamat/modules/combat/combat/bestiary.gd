class_name Bestiary
extends RefCounted

## The kinds of creature the player has defeated, across every save: the
## profile counts each kind (`GameProfile`, flag `defeated:<enemy id>`) as
## `CombatEvents.enemy_defeated` tells of it, and the pause menu's Bestiary
## lists the kinds met, weakest first, each with how often it fell, its health
## at the player's foe strength, how hard it hits and what it drops, and under
## it each elite form of it the player has defeated (`EliteData`, counted as
## `CombatEvents.elite_defeated` tells, flag `defeated:<elite id>:<enemy id>`).
## The profile also counts how many kinds the player has met (`KINDS_FLAG`),
## which an achievement for meeting every kind counts toward its goal.

## What the profile's count of a kind's defeats starts with.
const FLAG_PREFIX := "defeated:"
## The profile counter of how many of the game's kinds the player has
## defeated at least once, in every save: an achievement's `progress_flag`
## (Ember Depths' Know Thy Foe), whose progress the achievements menu shows.
const KINDS_FLAG := &"kinds_defeated"

## The profile flag that counts the defeats of kind `enemy_id`.
static func flag_of(enemy_id: StringName) -> StringName:
	return StringName(FLAG_PREFIX + String(enemy_id))

## How often the player has defeated kind `enemy_id`, in every save.
static func count(enemy_id: StringName) -> int:
	return GameProfile.get_int(flag_of(enemy_id))

## Counts a defeat of kind `enemy_id` (a kind of the game's content), and
## the kinds met once it is the first of its kind (a profile from before the
## counter catches up with the next defeat).
static func record(enemy_id: StringName, _combat_xp := 0, _position := Vector2.ZERO) -> void:
	if EnemyData.find(enemy_id) != null:
		GameProfile.add_int(flag_of(enemy_id), 1)
		GameProfile.raise_int(KINDS_FLAG, find_met().size())

## The game's kinds the player has defeated at least once, in every save,
## weakest first.
static func find_met() -> Array[EnemyData]:
	var met: Array[EnemyData] = []
	for enemy: EnemyData in _by_strength():
		if count(enemy.id) > 0:
			met.append(enemy)
	return met

## The profile flag that counts the defeats of kind `enemy_id` in elite form
## `elite_id`.
static func elite_flag_of(elite_id: StringName, enemy_id: StringName) -> StringName:
	return StringName("%s%s:%s" % [FLAG_PREFIX, elite_id, enemy_id])

## How often the player has defeated kind `enemy_id` in elite form
## `elite_id`, in every save.
static func count_elite(elite_id: StringName, enemy_id: StringName) -> int:
	return GameProfile.get_int(elite_flag_of(elite_id, enemy_id))

## Counts a defeat of kind `enemy_id` in elite form `elite_id` (both of the
## game's content).
static func record_elite(elite_id: StringName, enemy_id: StringName, _position := Vector2.ZERO) -> void:
	if EliteData.find(elite_id) != null and EnemyData.find(enemy_id) != null:
		GameProfile.add_int(elite_flag_of(elite_id, enemy_id), 1)

## The pause menu's Bestiary: how many kinds the player has met of the game's,
## then each kind met; nothing before the first.
static func describe() -> PackedStringArray:
	var lines := PackedStringArray()
	var met := find_met()
	if met.is_empty():
		return lines
	lines.append(TranslationServer.translate("Met %d of %d") % [met.size(), EnemyData.find_all().size()])
	for enemy: EnemyData in met:
		lines.append(TranslationServer.translate("%s — defeated %d") % [TranslationServer.translate(enemy.display_name), count(enemy.id)])
		var parts := PackedStringArray([TranslationServer.translate("Health %d") % HostileCreature.max_health_of(enemy)])
		if enemy.contact_damage > 0:
			var hits := TranslationServer.translate("Shoots for %d") if enemy.shot_speed > 0.0 else TranslationServer.translate("Hits for %d")
			parts.append(String(hits) % enemy.contact_damage)
		var drop := ItemData.find(enemy.drop_item_id)
		if drop != null:
			parts.append(TranslationServer.translate("Drops %s") % TranslationServer.translate(drop.display_name))
		lines.append("  " + " · ".join(parts))
		for elite: EliteData in EliteData.find_all():
			if count_elite(elite.id, enemy.id) > 0:
				lines.append("  " + TranslationServer.translate("%s — defeated %d") % [elite.name_of(enemy), count_elite(elite.id, enemy.id)])
	return lines

# The game's kinds, weakest first, then by id.
static func _by_strength() -> Array[EnemyData]:
	var enemies := EnemyData.find_all()
	enemies.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return a.max_health < b.max_health or (a.max_health == b.max_health and String(a.id) < String(b.id)))
	return enemies
