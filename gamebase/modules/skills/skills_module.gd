class_name SkillsModule
extends GameModule

## Wires the skills module into the core (see `GameModule`).

func install() -> void:
	SkillsRules.register(GameRules)
	SaveManager.register_section(SaveSection.new(&"skills", 1100,
		Skills.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Skills.load_save_data(section)))
	GameSession.register_new_game_step(&"skills", 800, Skills.reset_new_game)
