extends GutTest

## Ember Depths' forge at camp: lasting upgrades bought with what the runs
## brought back (`StatUpgradeData`), and the achievement for all of them.

const CAMP_SCENE := preload("res://game/world/camp.tscn")
const TEST_PROFILE := "user://test_forge/profile.json"

var _world: Dictionary
var _wallet: Dictionary
var _inventory: Dictionary
var _profile: Dictionary
var _profile_path: String

func before_each() -> void:
	_world = WorldState.to_save_data()
	_wallet = Wallet.to_save_data()
	_inventory = InventoryState.to_save_data()
	_profile = GameProfile.to_save_data()
	_profile_path = GameProfile.profile_path
	GameProfile.profile_path = TEST_PROFILE
	GameProfile.load_save_data({})
	WorldState.clear()
	InventoryState.clear()
	Wallet.set_money(0)

func after_each() -> void:
	InputLock.clear()
	WorldState.load_save_data(_world)
	Wallet.load_save_data(_wallet)
	InventoryState.load_save_data(_inventory)
	GameProfile.load_save_data(_profile)
	GameProfile.profile_path = _profile_path
	for path: String in [TEST_PROFILE, TEST_PROFILE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_the_forge_sells_lasting_upgrades_that_change_the_player() -> void:
	var camp := CAMP_SCENE.instantiate()
	add_child_autofree(camp)
	var forge := camp.get_node("EmberForge") as StatUpgradeStand
	assert_eq(forge.get_upgrades().map(func(upgrade: StatUpgradeData) -> StringName: return upgrade.id), [&"tempered_blade", &"hardened_hide", &"fleet_boots", &"ember_brand"], "in the forge's order, the locked brand last")
	Wallet.set_money(40)
	(func() -> void: await forge.browse()).call()
	var menu := forge.get_choice_menu()
	assert_eq((menu.get_node("%Title") as Label).text, "Ember Forge")
	assert_true(menu.get_button(&"ember_brand").disabled, "the brand waits for depth 10")
	assert_string_starts_with(menu.get_note(&"ember_brand"), "An ember core forged into the blade")
	assert_true(menu.choose(&"tempered_blade"))
	menu.close()
	assert_eq(Wallet.money, 0)
	assert_almost_eq(GameStats.apply(&"attack_damage", 10.0), 11.0, 0.001)

func test_every_upgrade_at_its_last_level_is_fully_forged() -> void:
	for upgrade_id: StringName in [&"tempered_blade", &"hardened_hide", &"fleet_boots"]:
		while StatUpgradeData.find(upgrade_id).raise():
			pass
	assert_false(GameProfile.is_unlocked(&"fully_forged"))
	GameProfile.unlock(&"ember_heart")
	InventoryState.add_item_by_id(&"ember_core", 2)
	Wallet.set_money(200)
	assert_true(StatUpgradeData.find(&"ember_brand").buy())
	assert_eq(InventoryState.get_quantity(&"ember_core"), 0)
	assert_true(GameProfile.is_unlocked(&"fully_forged"))
