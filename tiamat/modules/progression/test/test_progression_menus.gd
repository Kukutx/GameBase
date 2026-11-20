extends GutTest

## The progression module's menus, the town's projects, the tool upgrades and
## the mailbox, each opened on content of the test's own, full and empty: the
## focus starts in the menu on a control that works, and every control fits
## the view, a long list scrolling within it; the mailbox stays on the
## letter claimed from and the button pressed; and a project tells where to
## get a material the player still lacks.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")
const PROJECT_MENU := preload("res://tiamat/modules/progression/projects/town_project_menu.tscn")
const UPGRADE_MENU := preload("res://tiamat/modules/progression/upgrades/tool_upgrade_menu.tscn")
const MAILBOX_MENU := preload("res://tiamat/modules/progression/mail/mailbox_menu.tscn")
## More entries than any of the menus shows at once.
const ENTRY_COUNT := 8
const TOWN := &"fixture_menu_town"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _wallet_snapshot: Dictionary
var _vitals_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_wallet_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_wallet_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	InputLock.clear()

func test_each_menu_holds_the_focus_and_fits_the_view_with_a_long_list() -> void:
	var timber := _item(&"fixture_menu_timber", "Fixture Timber Of A Rather Long Name")
	var content: Array = [timber]
	for index: int in ENTRY_COUNT:
		content.append(_project(index, timber))
		content.append(_upgrade(index, timber))
		content.append(_mail(index))
	ContentFixture.use(self, content)
	Wallet.money = 999999
	InventoryState.add_item(timber, 99)
	MailState.refresh_deliveries()
	await _check(PROJECT_MENU, func(menu: Node) -> void: menu.call("open", TOWN))
	await _check(UPGRADE_MENU, func(menu: Node) -> void: menu.call("open"))
	await _check(MAILBOX_MENU, func(menu: Node) -> void: menu.call("open"))

func test_each_menu_holds_the_focus_and_fits_the_view_with_nothing_to_show() -> void:
	ContentFixture.use(self, [])
	await _check(PROJECT_MENU, func(menu: Node) -> void: menu.call("open", TOWN))
	await _check(UPGRADE_MENU, func(menu: Node) -> void: menu.call("open"))

func test_the_mailbox_stays_on_the_letter_claimed_from_and_the_button_pressed() -> void:
	var letters: Array[MailData] = [_mail(0), _mail(1), _mail(2)]
	letters[1].reward_money = 0
	ContentFixture.use(self, letters)
	MailState.refresh_deliveries()
	var menu := MAILBOX_MENU.instantiate() as MailboxMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open()
	assert_eq(menu.title_label.text, letters[0].subject, "the first unread letter")
	assert_true(menu.claim_button.has_focus(), "a letter with attachments opens on claiming them")
	# The two letters still unread would come first in the service's order.
	menu.claim_button.pressed.emit()
	assert_true(MailState.is_claimed(letters[0].id))
	assert_eq(menu.title_label.text, letters[0].subject, "a claim leaves the player on the letter")
	assert_true(menu.next_button.has_focus(), "a claim done hands the focus on to the next letter")
	menu.next_button.pressed.emit()
	assert_eq(menu.title_label.text, letters[1].subject)
	assert_true(menu.next_button.has_focus(), "Next pages on")
	menu.next_button.pressed.emit()
	assert_eq(menu.title_label.text, letters[2].subject)
	assert_true(menu.claim_button.has_focus(), "the last letter hands the focus from Next to its claim")
	menu.close()
	await get_tree().process_frame

func test_a_project_tells_where_to_get_a_material_the_player_lacks() -> void:
	var timber := _item(&"fixture_menu_timber", "Fixture Timber")
	var project := _project(0, timber)
	ContentFixture.use(self, [timber, project])
	var sources := ItemSources.new()
	sources.add(timber.id, "Sold at Fixture Mill")
	var menu := PROJECT_MENU.instantiate() as TownProjectMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	InventoryState.add_item(timber, 2)
	assert_string_contains(menu.project_text(project, sources), "Where to get: Sold at Fixture Mill")
	InventoryState.add_item(timber, 3)
	assert_false(menu.project_text(project, sources).contains("Where to get"), "the player carries what it still needs")

# Opens a menu of `scene` with `open`, and checks its focus and its fit.
func _check(scene: PackedScene, open: Callable) -> void:
	var menu := scene.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	open.call(menu)
	await get_tree().process_frame
	assert_eq(MenuFit.find_focus_problem(menu), "", scene.resource_path)
	# Containers sort their children on the frame after a change.
	await get_tree().process_frame
	assert_eq(await MenuFit.find_overflow_in_views(menu), PackedStringArray(), scene.resource_path)
	menu.call("close")
	await get_tree().process_frame

static func _item(id: StringName, display_name: String) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	return item

static func _project(index: int, material: ItemData) -> TownProjectData:
	var project := TownProjectData.new()
	project.id = StringName("fixture_menu_project_%02d" % index)
	project.display_name = "Restore The Fixture Bridge Over The Long River %02d" % index
	project.description = "The old bridge has stood for a hundred years and needs a great deal of timber before it stands for a hundred more."
	project.location_id = TOWN
	project.requirements = {String(material.id): 5}
	project.reward_money = 100
	return project

static func _upgrade(index: int, material: ItemData) -> ToolUpgradeData:
	var upgrade := ToolUpgradeData.new()
	upgrade.id = StringName("fixture_menu_upgrade_%02d" % index)
	upgrade.display_name = "Fixture Upgrade With A Rather Long Name %02d" % index
	upgrade.source_item_id = material.id
	upgrade.result_item_id = material.id
	upgrade.materials = {String(material.id): 2}
	upgrade.money_cost = 10
	return upgrade

static func _mail(index: int) -> MailData:
	var mail := MailData.new()
	mail.id = StringName("fixture_menu_mail_%02d" % index)
	mail.sender_name = "The Fixture Town Council"
	mail.subject = "A Letter With A Rather Long Subject %02d" % index
	mail.body = "Dear neighbour,\n\n" + "The town thanks you for all your help this season. ".repeat(12)
	mail.reward_money = 10
	return mail
