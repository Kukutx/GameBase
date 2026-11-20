extends GutTest

## The kinds of creature the player has defeated, counted in the profile
## across every save (`Bestiary`), and the pause menu's page of them.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const TEST_PATH := "user://test_bestiary/profile.json"

var _saved_path: String
var _saved_profile: Dictionary
var _options: GameOptions

func before_each() -> void:
	_saved_path = GameProfile.profile_path
	_saved_profile = GameProfile.to_save_data()
	_options = GameSettings.options
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})
	ContentFixture.use(self, _fixture_content())

func after_each() -> void:
	ContentRegistry.active = ContentDB
	GameSettings.options = _options
	GameProfile.load_save_data(_saved_profile)
	GameProfile.profile_path = _saved_path
	for path: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_each_defeat_counts_toward_its_kind_in_the_profile() -> void:
	assert_true(CombatEvents.enemy_defeated.is_connected(Bestiary.record), "the module counts every defeat")
	Bestiary.record(&"fixture_slime")
	Bestiary.record(&"fixture_slime")
	Bestiary.record(&"fixture_missing")
	assert_eq(Bestiary.count(&"fixture_slime"), 2)
	assert_eq(GameProfile.get_int(&"defeated:fixture_slime"), 2, "kept with the profile, across every save")
	assert_eq(Bestiary.count(&"fixture_missing"), 0, "a kind the game does not have is not counted")

func test_the_profile_counts_the_kinds_met_which_an_achievement_can_count() -> void:
	var know_them := AchievementData.new()
	know_them.id = &"fixture_know_them"
	know_them.display_name = "Know Them"
	know_them.description = "Defeat every kind."
	know_them.progress_flag = Bestiary.KINDS_FLAG
	know_them.goal = 3
	ContentFixture.use(self, _fixture_content() + [know_them])
	Bestiary.record(&"fixture_slime")
	Bestiary.record(&"fixture_slime")
	assert_eq(GameProfile.get_int(Bestiary.KINDS_FLAG), 1, "a kind again is not another kind")
	Bestiary.record(&"fixture_king")
	Bestiary.record(&"fixture_missing")
	assert_eq(GameProfile.get_int(Bestiary.KINDS_FLAG), 2, "a kind the game does not have is none")
	assert_eq(Bestiary.find_met().map(func(enemy: EnemyData) -> StringName: return enemy.id), [&"fixture_slime", &"fixture_king"], "weakest first")
	assert_eq(GameProfile.get_progress(&"fixture_know_them"), 2)
	assert_false(GameProfile.is_unlocked(&"fixture_know_them"))
	GameProfile.set_flag(Bestiary.flag_of(&"fixture_bat"), 4)
	Bestiary.record(&"fixture_slime")
	assert_eq(GameProfile.get_int(Bestiary.KINDS_FLAG), 3, "a profile from before the counter catches up with the next defeat")
	assert_true(GameProfile.is_unlocked(&"fixture_know_them"))

func test_the_bestiary_lists_the_kinds_met_weakest_first() -> void:
	assert_eq(Bestiary.describe(), PackedStringArray(), "nothing before the first defeat")
	Bestiary.record(&"fixture_king")
	Bestiary.record(&"fixture_slime")
	Bestiary.record(&"fixture_slime")
	assert_eq(Bestiary.describe(), PackedStringArray([
		"Met 2 of 3",
		"Slime — defeated 2",
		"  Health 30 · Hits for 8 · Drops Gel",
		"Slime King — defeated 1",
		"  Health 300 · Hits for 20 · Drops Gel",
	]))
	EnemyData.find(&"fixture_king").shot_speed = 120.0
	assert_string_contains("\n".join(Bestiary.describe()), "Health 300 · Shoots for 20 ·", "a kind that shoots from afar says so")
	GameSettings.options = GameOptions.new(CombatModule.new().get_options())
	GameSettings.options.set_value(HostileCreature.STRENGTH_OPTION, "Strong")
	assert_string_contains("\n".join(Bestiary.describe()), "Health 45 ·", "at the player's foe strength")
	assert_true(PauseMenu.get_page_ids().has(&"bestiary"))

func test_a_kind_tells_what_it_inflicts_and_what_it_is_immune_to() -> void:
	var slime := EnemyData.find(&"fixture_slime")
	slime.affliction_id = &"fixture_burn"
	slime.immune_to.assign([&"fixture_poison", &"fixture_missing"])
	Bestiary.record(&"fixture_slime")
	assert_eq(Bestiary.describe()[2], "  Health 30 · Hits for 8 · Inflicts Burning · Immune to Poison · Drops Gel")

func test_each_elite_form_defeated_shows_under_its_kind() -> void:
	assert_true(CombatEvents.elite_defeated.is_connected(Bestiary.record_elite), "the module counts every elite")
	Bestiary.record(&"fixture_slime")
	Bestiary.record(&"fixture_slime")
	Bestiary.record_elite(&"fixture_hulking", &"fixture_slime")
	Bestiary.record_elite(&"fixture_hulking", &"fixture_slime")
	Bestiary.record_elite(&"fixture_missing", &"fixture_slime")
	assert_eq(Bestiary.count_elite(&"fixture_hulking", &"fixture_slime"), 2)
	assert_eq(GameProfile.get_int(&"defeated:fixture_hulking:fixture_slime"), 2)
	assert_eq(Bestiary.count_elite(&"fixture_missing", &"fixture_slime"), 0, "a form the game does not have is not counted")
	assert_eq(Bestiary.describe(), PackedStringArray([
		"Met 1 of 3",
		"Slime — defeated 2",
		"  Health 30 · Hits for 8 · Drops Gel",
		"  Hulking Slime — defeated 2",
	]))

func _fixture_content() -> Array:
	var gel := ItemData.new()
	gel.id = &"fixture_gel"
	gel.display_name = "Gel"
	var hulking := EliteData.new()
	hulking.id = &"fixture_hulking"
	hulking.display_name = "Hulking %s"
	return [gel, _enemy(&"fixture_slime", "Slime", 30, 8, gel.id), _enemy(&"fixture_king", "Slime King", 300, 20, gel.id),
		_enemy(&"fixture_bat", "Bat", 12, 4, &""), hulking, _affliction(&"fixture_burn", "Burning"), _affliction(&"fixture_poison", "Poison")]

static func _affliction(id: StringName, display_name: String) -> AfflictionData:
	var affliction := AfflictionData.new()
	affliction.id = id
	affliction.display_name = display_name
	return affliction

static func _enemy(id: StringName, display_name: String, health: int, damage: int, drop: StringName) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = id
	enemy.display_name = display_name
	enemy.max_health = health
	enemy.contact_damage = damage
	enemy.drop_item_id = drop
	return enemy
