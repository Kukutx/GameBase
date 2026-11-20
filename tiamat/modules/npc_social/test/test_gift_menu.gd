extends GutTest

## The gift menu (`GiftMenu`): it lists the gifts the player carries with how
## the NPC took each before, picks the item in hand first, gives the one picked
## and closes, and does not open once the NPC had a gift today or with nothing
## to give.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")
const GIFT_MENU := preload("res://tiamat/modules/npc_social/npc/gift_menu.tscn")

var _inventory_snapshot: Dictionary
var _relationship_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _profile: NpcProfileData

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_relationship_snapshot = RelationshipState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	InventoryState.clear()
	RelationshipState.clear()
	WorldClock.set_time(3, 10 * 60)
	_profile = NpcProfileData.new()
	_profile.id = &"fixture_gift_npc"
	_profile.display_name = "Fixture"
	_profile.loved_items = [&"fixture_berry"]
	ContentFixture.use(self, [_profile, _item(&"fixture_berry", ItemData.Kind.GIFT), _item(&"fixture_radish", ItemData.Kind.CROP),
		_item(&"fixture_seeds", ItemData.Kind.SEED), _item(&"fixture_letter", ItemData.Kind.QUEST)])

func after_each() -> void:
	# The game's content is active again before the inventory loads its items.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	RelationshipState.load_save_data(_relationship_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	InputLock.clear()

func test_the_menu_lists_the_gifts_carried_with_how_they_were_taken_and_gives_the_one_picked() -> void:
	for item_id: StringName in [&"fixture_berry", &"fixture_radish", &"fixture_seeds", &"fixture_letter"]:
		InventoryState.add_item_by_id(item_id, 2)
	RelationshipState.give_gift(_profile, &"fixture_berry")
	WorldClock.set_time(4, 10 * 60)
	var menu := GIFT_MENU.instantiate() as GiftMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	assert_true(menu.open(_profile, &"fixture_radish"))
	assert_eq(menu.item_list.item_count, 2, "neither seeds nor a quest item are gifts")
	assert_eq(menu.item_list.get_item_text(0), "Fixture Berry x1 · " + tr("Loved"), "what the last gift told")
	assert_eq(menu.item_list.get_item_text(1), "Fixture Radish x2")
	assert_eq(menu.item_list.get_selected_items(), PackedInt32Array([1]), "the item in hand is picked first")
	await get_tree().process_frame
	assert_eq(MenuFit.find_focus_problem(menu), "")
	await get_tree().process_frame
	assert_eq(await MenuFit.find_overflow_in_views(menu), PackedStringArray())
	assert_eq(menu.give_selected(), _profile.friendship_for_gift(ItemData.find(&"fixture_radish")))
	assert_false(menu.visible, "a gift given closes the menu")
	assert_eq(InventoryState.get_quantity(&"fixture_radish"), 1)
	assert_eq(RelationshipState.get_known_taste(_profile.id, &"fixture_radish"), NpcProfileData.Taste.NEUTRAL)
	assert_false(menu.open(_profile), "one gift a day")
	assert_false(menu.visible)

func test_the_menu_does_not_open_with_nothing_to_give() -> void:
	InventoryState.add_item_by_id(&"fixture_seeds", 3)
	var menu := GIFT_MENU.instantiate() as GiftMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	assert_false(menu.open(_profile))
	assert_false(menu.visible)

static func _item(id: StringName, kind: ItemData.Kind) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = kind
	return item
