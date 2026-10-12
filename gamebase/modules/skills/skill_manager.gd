class_name SkillManager
extends Node

## The player's experience and level in each of the game's skills
## (`SkillData`), and the stat changes of the perks those levels unlock: a
## source of `GameStats`.

signal skill_xp_changed(skill: StringName, xp: int, level: int)
signal skill_leveled_up(skill: StringName, level: int)

## Experience of each skill that has some, as skill id -> amount.
var _xp: Dictionary[StringName, int] = {}

## Adds experience to a skill. What earns experience is the game's to decide,
## in data: a trigger on a module event it chooses runs `ADD_SKILL_XP`
## (`TriggerData`; Farm1's `game/data/triggers/`).
func add_xp(skill: StringName, amount: int) -> int:
	var data := SkillData.find(skill)
	if data == null:
		return 0
	if amount <= 0:
		return get_xp(skill)
	var old_level := get_level(skill)
	var next := get_xp(skill) + amount
	_xp[skill] = next
	var level := data.get_level_for_xp(next)
	skill_xp_changed.emit(skill, next, level)
	if level > old_level:
		skill_leveled_up.emit(skill, level)
		if is_inside_tree():
			GameEvents.toastf("%s reached level %d", [data.display_name, level])
	return next

## The skill's translated name.
func get_skill_name(skill: StringName) -> String:
	var data := SkillData.find(skill)
	return tr(data.display_name) if data != null else String(skill)

func get_xp(skill: StringName) -> int:
	return maxi(_xp.get(skill, 0), 0)

func get_level(skill: StringName) -> int:
	var data := SkillData.find(skill)
	return data.get_level_for_xp(get_xp(skill)) if data != null else 1

## The perk the skill's level has unlocked, or null.
func get_active_perk(skill: StringName) -> SkillPerk:
	var data := SkillData.find(skill)
	return data.get_perk_at(get_level(skill)) if data != null else null

## `GameStats` source: the product of the active perks' multipliers of `stat`.
func get_stat_multiplier(stat: StringName) -> float:
	var result := 1.0
	for perk: SkillPerk in _get_active_perks():
		result *= perk.multipliers.get(stat, 1.0)
	return result

## `GameStats` source: the sum of the active perks' bonuses to `stat`.
func get_stat_bonus(stat: StringName) -> float:
	var result := 0.0
	for perk: SkillPerk in _get_active_perks():
		result += perk.bonuses.get(stat, 0.0)
	return result

## The skill's active perk as the player reads it, or the level of its next.
func get_perk_summary(skill: StringName) -> String:
	var data := SkillData.find(skill)
	if data == null:
		return ""
	var perk := data.get_perk_at(get_level(skill))
	if perk != null:
		return tr(perk.description)
	var next := data.get_next_perk(get_level(skill))
	return tr("Next passive at Lv%d") % next.level if next != null else ""

## Every skill's short name and level on one line.
func get_summary() -> String:
	var parts := PackedStringArray()
	for data: SkillData in SkillData.find_all():
		parts.append("%s %d" % [tr(data.get_short_name()), get_level(data.id)])
	return " · ".join(parts)

func reset_new_game() -> void:
	_xp.clear()
	for data: SkillData in SkillData.find_all():
		skill_xp_changed.emit(data.id, 0, 1)

## Each skill's experience, as skill id -> amount.
func to_save_data() -> Dictionary:
	var data: Dictionary = {}
	for skill: SkillData in SkillData.find_all():
		data[String(skill.id)] = get_xp(skill.id)
	return data

## Restores the saved skills; a skill the game does not have is dropped.
func load_save_data(data: Dictionary) -> void:
	_xp.clear()
	for skill: SkillData in SkillData.find_all():
		var xp := maxi(SaveValues.whole_number_or(data.get(String(skill.id), 0), 0), 0)
		if xp > 0:
			_xp[skill.id] = xp
		skill_xp_changed.emit(skill.id, xp, skill.get_level_for_xp(xp))

# Only a skill with experience can have a perk.
func _get_active_perks() -> Array[SkillPerk]:
	var perks: Array[SkillPerk] = []
	for skill: StringName in _xp:
		var perk := get_active_perk(skill)
		if perk != null:
			perks.append(perk)
	return perks
