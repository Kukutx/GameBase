class_name SkillsModule
extends GameModule

## Wires the skills module into the core (see `GameModule`).

func install() -> void:
	ContentDB.register_kind(SkillData.KIND, SkillData)
	GameStats.register_source(Skills)
	SkillsRules.register(GameRules)
	SaveManager.register_section(SaveSection.new(&"skills", 1100,
		Skills.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Skills.load_save_data(section)))
	GameSession.register_new_game_step(&"skills", 800, Skills.reset_new_game)

## Each skill's level and experience.
func get_facts() -> Dictionary:
	var skills := {}
	for skill: SkillData in SkillData.find_all():
		skills[String(skill.id)] = {"level": Skills.get_level(skill.id), "xp": Skills.get_xp(skill.id)}
	return {"skills": skills}
