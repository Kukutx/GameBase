extends GutTest

## A defeat (`PlayerDefeat`, `CombatSettings`): what it costs and what the
## player wakes with, and the settings' problems.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const HP := &"fixture_hp"
const STAMINA := &"fixture_stamina"

var _vitals_snapshot: Dictionary
var _wallet_snapshot: Dictionary
var _settings: CombatSettings

func before_each() -> void:
	_vitals_snapshot = Vitals.to_save_data()
	_wallet_snapshot = Wallet.to_save_data()
	ContentFixture.use(self, [ContentFixture.vital(HP), ContentFixture.vital(STAMINA, 50, false)])
	_settings = CombatSettings.new()
	_settings.health_vital_id = HP
	_settings.defeat_money_loss_percent = 25
	ContentFixture.use_settings(self, [_settings])
	Vitals.reset_new_game()

func after_each() -> void:
	ContentRegistry.active = ContentDB
	Vitals.load_save_data(_vitals_snapshot)
	Wallet.load_save_data(_wallet_snapshot)

func test_a_defeat_costs_its_share_of_the_money_and_refills_every_vital() -> void:
	Wallet.set_money(30)
	Vitals.set_value(STAMINA, 3)
	var loss := [0]
	PlayerDefeat.call("_recover", loss)
	assert_eq(loss[0], 8, "a quarter of 30, rounded up")
	assert_eq(Wallet.money, 22)
	assert_true(Vitals.is_full(HP))
	assert_true(Vitals.is_full(STAMINA), "also what sleep does not refill")

func test_a_defeat_of_a_game_without_a_loss_costs_nothing() -> void:
	_settings.defeat_money_loss_percent = 0
	Wallet.set_money(30)
	var loss := [0]
	PlayerDefeat.call("_recover", loss)
	assert_eq(loss[0], 0)
	assert_eq(Wallet.money, 30)

func test_the_settings_problems_are_named() -> void:
	var registry := ContentRegistry.active
	assert_eq(CombatSettings.new().find_problems(registry), PackedStringArray(), "the defaults: hits hurt nothing, swings are free")
	var settings := CombatSettings.new()
	settings.health_vital_id = &"fixture_life"
	settings.attack_vital_id = STAMINA
	assert_eq(settings.find_problems(registry), PackedStringArray(["health vital 'fixture_life' is no vital"]))
