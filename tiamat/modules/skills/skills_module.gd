class_name SkillsModule
extends GameModule

## Wires the skills module into the core (see `GameModule`).

func install() -> void:
	ContentDB.register_kind(SkillData.KIND, SkillData)
	GameStats.register_source(Skills)
	# A level reached may bring a perk's changes.
	Skills.skill_xp_changed.connect(GameStats.notify_changed.unbind(3))
	SkillsRules.register(GameRules)
	PauseMenu.add_page(&"skills", "Skills", 20, describe_skills)
	SaveManager.register_section(SaveSection.new(&"skills", 1100,
		Skills.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Skills.load_save_data(section)))
	GameSession.register_new_game_step(&"skills", 800, Skills.reset_new_game)

## Each skill's level and experience.
func get_facts() -> Dictionary:
	var skills := {}
	for skill: SkillData in SkillData.find_all():
		skills[String(skill.id)] = {"level": Skills.get_level(skill.id), "xp": Skills.get_xp(skill.id)}
	return {"skills": skills}

## How far each skill is, for the pause menu's Skills: its level and the
## experience toward the next, then its perk or the level of its next.
static func describe_skills() -> PackedStringArray:
	var lines := PackedStringArray()
	for skill: SkillData in SkillData.find_all():
		var level := Skills.get_level(skill.id)
		var skill_name := TranslationServer.translate(skill.display_name)
		if level >= skill.get_max_level():
			lines.append(TranslationServer.translate("%s Lv %d (max)") % [skill_name, level])
		else:
			lines.append(TranslationServer.translate("%s Lv %d · %d/%d XP") % [skill_name, level, Skills.get_xp(skill.id), skill.level_xp[level - 1]])
		var perk := Skills.get_perk_summary(skill.id)
		if not perk.is_empty():
			lines.append("  " + perk)
	return lines
