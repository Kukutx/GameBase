extends GutTest

## The player's money (`Wallet`), what a new game starts with
## (`ItemsSettings`) and the share that carries over (`MoneyInheritance`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _wallet: Dictionary

func before_each() -> void:
	_wallet = Wallet.to_save_data()

func after_each() -> void:
	Wallet.load_save_data(_wallet)

func test_money_never_drops_below_nothing() -> void:
	Wallet.set_money(100)
	watch_signals(Wallet)
	Wallet.add(20)
	assert_eq(Wallet.money, 120)
	assert_true(Wallet.can_afford(120))
	assert_false(Wallet.spend(121), "not that much")
	assert_false(Wallet.spend(-5))
	assert_true(Wallet.spend(0), "nothing costs nothing")
	assert_true(Wallet.spend(100))
	assert_eq(Wallet.lose(50), 20, "a loss takes what there is")
	assert_eq(Wallet.money, 0)
	assert_eq(Wallet.lose(5), 0)
	Wallet.add(-3)
	assert_eq(Wallet.money, 0)
	assert_signal_emit_count(Wallet, "money_changed", 3)

func test_a_new_game_starts_with_the_game_s_money_and_a_save_keeps_it() -> void:
	var settings := ItemsSettings.new()
	settings.start_money = 75
	ContentFixture.use_settings(self, [settings])
	Wallet.set_money(3)
	Wallet.reset_new_game()
	assert_eq(Wallet.money, 75)
	var snapshot := {String(WalletService.SAVE_SECTION): Wallet.to_save_data()}
	assert_eq(WalletService.read_money(snapshot), 75)
	assert_eq(Wallet.describe_save(snapshot), "75g")
	assert_eq(Wallet.describe(), "75g")
	Wallet.load_save_data({"money": -40})
	assert_eq(Wallet.money, 0, "a damaged save holds no debt")
	assert_eq(WalletService.read_money({}), 0)

func test_a_share_of_the_money_carries_over() -> void:
	var rule := MoneyInheritance.new()
	rule.percent = 50
	Wallet.set_money(301)
	assert_eq(rule.capture(), 150, "rounded down")
	rule.apply(40)
	assert_eq(Wallet.money, 341)
	for bad: Variant in [-40, "lots", [1], null, 2.5]:
		rule.apply(bad)
	assert_eq(Wallet.money, 341, "only a whole amount carries")

func test_the_items_settings_name_items_the_game_has() -> void:
	var seed := ItemData.new()
	seed.id = &"fixture_seed"
	seed.display_name = "Seed"
	var registry := ContentFixture.use(self, [seed])
	var settings := ItemsSettings.new()
	settings.start_items = {&"fixture_seed": 2, &"fixture_ghost": 1}
	settings.start_hotbar = [&"fixture_seed", &"", &"fixture_lamp"]
	assert_eq(settings.find_problems(registry), PackedStringArray([
		"start item 'fixture_ghost' is no item",
		"start hotbar item 'fixture_lamp' is no item",
	]))
