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
	GameSettings.options = GameOptions.new(CombatModule.new().get_options())
	GameSettings.options.set_value(HostileCreature.STRENGTH_OPTION, "Strong")
	assert_string_contains("\n".join(Bestiary.describe()), "Health 45 ·", "at the player's foe strength")
	assert_true(PauseMenu.get_page_ids().has(&"bestiary"))

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
		_enemy(&"fixture_bat", "Bat", 12, 4, &""), hulking]

static func _enemy(id: StringName, display_name: String, health: int, damage: int, drop: StringName) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = id
	enemy.display_name = display_name
	enemy.max_health = health
	enemy.contact_damage = damage
	enemy.drop_item_id = drop
	return enemy
