extends GutTest

## Every place of the game shows its text in the language the player picks,
## also when they pick it while there (`GameSettings.locale_changed`): each
## location's scene is entered in one language, the language changed, and
## every text it shows then reads as it does in the scene entered afresh in
## the new one, both ways between the source language and another. A label
## that holds its text as written (a name, "Mailbox") follows by itself; one
## its node writes out ("Mailbox · 2 new", "Wild Berry x3") is written again.

var _locale: String
var _clock_paused: bool

func before_each() -> void:
	_locale = GameSettings.locale
	_clock_paused = WorldClock.paused
	WorldClock.paused = true

func after_each() -> void:
	GameSettings.set_locale(_locale)
	WorldClock.paused = _clock_paused

func test_every_place_s_text_follows_a_change_of_language() -> void:
	var others := Array(GameLocales.supported()).filter(func(locale: String) -> bool: return locale != GameLocales.SOURCE)
	if others.is_empty():
		pass_test("the game speaks one language")
		return
	var stale := PackedStringArray()
	for location: WorldLocationData in ContentRegistry.active.get_entries(WorldLocationData.KIND):
		if location.scene_path.is_empty() or not ResourceLoader.exists(location.scene_path):
			continue
		var packed := load(location.scene_path) as PackedScene
		for pair: Array in [[String(others[0]), GameLocales.SOURCE], [GameLocales.SOURCE, String(others[0])]]:
			GameSettings.set_locale(pair[0])
			var changed := await _texts_of(packed, pair[1])
			var fresh := await _texts_of(packed, "")
			for path: String in changed:
				if fresh.has(path) and fresh[path] != changed[path]:
					stale.append("%s %s in %s: '%s', afresh '%s'" % [location.id, path, pair[1], changed[path], fresh[path]])
	assert_eq(stale, PackedStringArray())

# The texts of a scene of `packed`, by node path: as it shows them once the
# language is changed to `locale`, or as it shows them on entering when empty.
func _texts_of(packed: PackedScene, locale: String) -> Dictionary:
	var view := SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	var root := packed.instantiate()
	view.add_child(root)
	await get_tree().process_frame
	if not locale.is_empty():
		GameSettings.set_locale(locale)
		await get_tree().process_frame
	var texts := {}
	_collect(root, root, texts)
	remove_child(view)
	view.free()
	return texts

# A menu kept hidden shows its text afresh as it opens.
func _collect(root: Node, node: Node, texts: Dictionary) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	var text := ""
	if node is Label:
		text = (node as Label).text
	elif node is RichTextLabel:
		text = (node as RichTextLabel).text
	elif node is Button:
		text = (node as Button).text
	elif node is Label3D:
		text = (node as Label3D).text
	if not text.is_empty():
		texts[String(root.get_path_to(node))] = node.atr(text)
	for child: Node in node.get_children():
		_collect(root, child, texts)
