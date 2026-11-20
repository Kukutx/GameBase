class_name Bestiary
extends RefCounted

## The kinds of creature the player has defeated, across every save: the
## profile counts each kind (`GameProfile`, flag `defeated:<enemy id>`) as
## `CombatEvents.enemy_defeated` tells of it, and the pause menu's Bestiary
## lists the kinds met, weakest first, each with how often it fell, its health
## at the player's foe strength, how hard it hits and what it drops.

## What the profile's count of a kind's defeats starts with.
const FLAG_PREFIX := "defeated:"

## The profile flag that counts the defeats of kind `enemy_id`.
static func flag_of(enemy_id: StringName) -> StringName:
	return StringName(FLAG_PREFIX + String(enemy_id))

## How often the player has defeated kind `enemy_id`, in every save.
static func count(enemy_id: StringName) -> int:
	return GameProfile.get_int(flag_of(enemy_id))

## Counts a defeat of kind `enemy_id` (a kind of the game's content).
static func record(enemy_id: StringName, _combat_xp := 0, _position := Vector2.ZERO) -> void:
	if EnemyData.find(enemy_id) != null:
		GameProfile.add_int(flag_of(enemy_id), 1)

## The pause menu's Bestiary: how many kinds the player has met of the game's,
## then each kind met; nothing before the first.
static func describe() -> PackedStringArray:
	var lines := PackedStringArray()
	var enemies := EnemyData.find_all()
	enemies.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return a.max_health < b.max_health or (a.max_health == b.max_health and String(a.id) < String(b.id)))
	var met := enemies.filter(func(enemy: EnemyData) -> bool: return count(enemy.id) > 0)
	if met.is_empty():
		return lines
	lines.append(TranslationServer.translate("Met %d of %d") % [met.size(), enemies.size()])
	for enemy: EnemyData in met:
		lines.append(TranslationServer.translate("%s — defeated %d") % [TranslationServer.translate(enemy.display_name), count(enemy.id)])
		var parts := PackedStringArray([TranslationServer.translate("Health %d") % HostileCreature.max_health_of(enemy)])
		if enemy.contact_damage > 0:
			parts.append(TranslationServer.translate("Hits for %d") % enemy.contact_damage)
		var drop := ItemData.find(enemy.drop_item_id)
		if drop != null:
			parts.append(TranslationServer.translate("Drops %s") % TranslationServer.translate(drop.display_name))
		lines.append("  " + " · ".join(parts))
	return lines
