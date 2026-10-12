class_name SkillInheritance
extends InheritanceRule

## Carries a share of each skill's experience over (`Playthrough`), rounded
## down; a skill the new game's content does not have is left behind.

@export_range(0, 100, 1) var percent := 100

func _init() -> void:
	key = &"skills"

func capture() -> Variant:
	var experience: Dictionary = {}
	for skill: SkillData in SkillData.find_all():
		var xp := floori(Skills.get_xp(skill.id) * percent / 100.0)
		if xp > 0:
			experience[String(skill.id)] = xp
	return experience

func apply(data: Variant) -> void:
	if not data is Dictionary:
		return
	var carried: Dictionary = data
	var experience := Skills.to_save_data()
	for skill: SkillData in SkillData.find_all():
		var id := String(skill.id)
		experience[id] = int(experience.get(id, 0)) + SaveValues.count(carried.get(id, 0))
	Skills.load_save_data(experience)
