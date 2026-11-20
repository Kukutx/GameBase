class_name GiftMenu
extends MenuLayer

## Picks a gift for an NPC: every item the player carries that is a gift
## (`RelationshipManager.is_gift()`), each with how the NPC took it before
## where a gift told the player (`RelationshipManager.get_known_taste()`), the
## item in hand picked first. Give hands the one picked over, the NPC's gift of
## the day (`RelationshipManager.give_gift()`), and closes. A game puts it in
## its HUD; its player opens it with the gift control near an NPC.

@onready var title_label: Label = $Panel/VBox/Title
@onready var note_label: Label = $Panel/VBox/Note
@onready var item_list: ItemList = $Panel/VBox/Items
@onready var give_button: Button = $Panel/VBox/Actions/Give
@onready var close_button: Button = $Panel/VBox/Actions/Close

var _profile: NpcProfileData

func _init() -> void:
	super(&"gift_menu")

func _ready() -> void:
	give_button.pressed.connect(give_selected)
	close_button.pressed.connect(close)
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)

## Shows the gifts the player can give `profile`, `picked` first when it is
## one; false, with a toast, while they gave them one today or carry none.
func open(profile: NpcProfileData, picked: StringName = &"") -> bool:
	if profile == null:
		return false
	if RelationshipState.has_given_gift_today(profile.id):
		GameEvents.toastf("You already gave %s a gift today", [profile.display_name])
		return false
	var rows := _rows(profile)
	if rows.is_empty():
		GameEvents.toast("You carry nothing to give")
		return false
	_profile = profile
	title_label.text = tr("A gift for %s") % tr(profile.display_name)
	note_label.text = tr("Their birthday: a gift counts twice") if profile.is_birthday() else ""
	note_label.visible = not note_label.text.is_empty()
	item_list.clear()
	MenuLayer.refill_list(item_list, rows)
	var at := 0
	for index: int in item_list.item_count:
		if item_list.get_item_metadata(index) == picked:
			at = index
	item_list.select(at)
	item_list.ensure_current_is_visible()
	give_button.disabled = false
	show_menu()
	MenuLayer.focus(item_list)
	return true

## The NPC the menu picks a gift for, or null.
func get_profile() -> NpcProfileData:
	return _profile

## Gives the item picked; the friendship it gave, 0 for none.
func give_selected() -> int:
	var selected := item_list.get_selected_items()
	if _profile == null or selected.is_empty():
		return 0
	var item_id := StringName(String(item_list.get_item_metadata(int(selected[0]))))
	var profile := _profile
	close()
	return RelationshipState.give_gift(profile, item_id)

func close() -> void:
	_profile = null
	super()

## What the list tells of an item the NPC was found to take as `taste`
## (`NpcProfileData.Taste`), "" while it is not known.
static func taste_word(taste: int) -> String:
	match taste:
		NpcProfileData.Taste.LOVED: return String(TranslationServer.translate("Loved"))
		NpcProfileData.Taste.LIKED: return String(TranslationServer.translate("Liked"))
		NpcProfileData.Taste.NEUTRAL: return String(TranslationServer.translate("Neutral"))
		NpcProfileData.Taste.DISLIKED: return String(TranslationServer.translate("Disliked"))
	return ""

# The list's rows: each gift carried, with how `profile` took it before.
static func _rows(profile: NpcProfileData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in InventoryState.get_entries():
		var item := ItemData.find(StringName(String(entry["id"])))
		if not RelationshipManager.is_gift(item):
			continue
		var text := "%s x%d" % [TranslationServer.translate(item.display_name), int(entry["quantity"])]
		var word := taste_word(RelationshipState.get_known_taste(profile.id, item.id))
		if not word.is_empty():
			text += " · " + word
		rows.append({"text": text, "key": item.id, "icon": item.icon})
	return rows

func _on_item_selected(_index: int) -> void:
	give_button.disabled = not item_list.is_anything_selected()

func _on_item_activated(_index: int) -> void:
	give_selected()
