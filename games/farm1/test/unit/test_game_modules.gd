extends GutTest

func test_every_linked_module_installed_itself() -> void:
	assert_eq(GameModules.get_installed(), PackedStringArray([
		"ItemsModule", "LifesimModule", "NpcSocialModule", "ProgressionModule", "SkillsModule",
	]))

